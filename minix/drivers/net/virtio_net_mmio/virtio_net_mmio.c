/* virtio net driver for MINIX 3 (MMIO / RISC-V)
 *
 * Copyright (c) 2013, A. Welzel, <arne.welzel@gmail.com>
 *
 * Datapath follows FreeBSD if_vtnet: modern virtio_net_hdr (12 bytes
 * when VIRTIO_F_VERSION_1), mergeable RX buffers, TX partial checksum,
 * RX NEEDS_CSUM fixup, CTRL_VQ RX filter / announce, config-change
 * link status, and VIRTIO_RING_F_EVENT_IDX. Kick RX/TX/CTRL after a
 * batch: EVENT_IDX in to_queue only notifies the first posted slot.
 * Drain the used ring after TX and on a tick: virtio-blk busy-waits
 * on from_queue, but net only looked at RX from IRQ, so a missed
 * first EVENT_IDX used-notify left slirp replies sitting in the ring.
 *
 * This software is released under the BSD license. See the LICENSE file
 * included in the main directory of this source distribution for the
 * license terms and conditions.
 */

#include <assert.h>
#include <string.h>
#include <sys/types.h>

#include <minix/drivers.h>
#include <minix/netdriver.h>
#include <minix/virtio_mmio.h>

#include <sys/queue.h>
#include <net/if_media.h>

#include "virtio_net.h"

#define VERBOSE 0

#if VERBOSE
#define dput(s)		do { dprintf(s); printf("\n"); } while (0)
#define dprintf(s) do {						\
	printf("%s: ", netdriver_name());			\
	printf s;						\
} while (0)
#else
#define dput(s)
#define dprintf(s)
#endif

static struct virtio_mmio_dev *net_dev;

enum queue {RX_Q, TX_Q, CTRL_Q};

#define RX_PACKETS		256
#define TX_PACKETS		256
#define BUF_PACKETS		(RX_PACKETS + TX_PACKETS)
#define MAX_PACK_SIZE		NDEV_ETH_PACKET_MAX
#define PACKET_BUF_SZ		(BUF_PACKETS * pkt_slot_sz)

#define ETHER_HDR_LEN		14
#define ETHERTYPE_IP		0x0800
#define ETHERTYPE_IPV6		0x86dd
#define ETHERTYPE_VLAN		0x8100
#define IPPROTO_TCP		6
#define IPPROTO_UDP		17
#define TCP_CSUM_OFF		16
#define UDP_CSUM_OFF		6

#define CTRL_MEM_SZ		256
#define CTRL_HDR_OFF		0
#define CTRL_ACK_OFF		2
#define CTRL_BYTE_OFF		4
#define CTRL_MACADDR_OFF	8
#define CTRL_UNI_OFF		16
#define CTRL_MULTI_OFF		32
#define CTRL_MCAST_MAX		16
#define CTRL_POLL_MAX		10000

struct packet {
	int idx;
	char *vbuf;
	phys_bytes pbuf;
	struct virtio_net_hdr *vhdr;
	char *vdata;
	size_t len;
	STAILQ_ENTRY(packet) next;
};

static char *data_vir;
static phys_bytes data_phys;
static struct packet *packets;
static int in_rx;
static size_t net_hdr_size;
static size_t pkt_slot_sz;
static uint32_t enabled_caps;
static netdriver_addr_t hwaddr;
static uint8_t *ctrl_vir;
static phys_bytes ctrl_phys;
static int have_ctrl;
static int have_rx_extra;
static int have_mac_ctrl;
static int have_mrg;
static int have_announce;

static STAILQ_HEAD(pkt_list, packet) rx_free, tx_free, recv_list;

static int spurious_interrupt;

static int virtio_net_probe(unsigned int skip);
static void virtio_net_config(netdriver_addr_t *addr);
static int virtio_net_alloc_bufs(void);
static void virtio_net_init_queues(void);

static void virtio_net_refill_rx_queue(void);
static void virtio_net_check_queues(void);
static void virtio_net_check_pending(void);

static int virtio_net_init(unsigned int instance, netdriver_addr_t * addr,
	uint32_t * caps, unsigned int * ticks);
static void virtio_net_stop(void);
static int virtio_net_send(struct netdriver_data *data, size_t len);
static ssize_t virtio_net_recv(struct netdriver_data *data, size_t max);
static unsigned int virtio_net_get_link(uint32_t *media);
static void virtio_net_intr(unsigned int mask);
static void virtio_net_tick(void);
static void virtio_net_set_mode(unsigned int mode,
	const netdriver_addr_t * mcast_list, unsigned int mcast_count);
static void virtio_net_set_caps(uint32_t caps);
static void virtio_net_set_hwaddr(const netdriver_addr_t * addr);

static const struct netdriver virtio_net_table = {
	.ndr_name	= "vio",
	.ndr_init	= virtio_net_init,
	.ndr_stop	= virtio_net_stop,
	.ndr_set_mode	= virtio_net_set_mode,
	.ndr_set_caps	= virtio_net_set_caps,
	.ndr_set_hwaddr	= virtio_net_set_hwaddr,
	.ndr_recv	= virtio_net_recv,
	.ndr_send	= virtio_net_send,
	.ndr_get_link	= virtio_net_get_link,
	.ndr_intr	= virtio_net_intr,
	.ndr_tick	= virtio_net_tick,
};

/*
 * Guest bits are offers; host_supports() after setup is the negotiated set.
 * MRG_RXBUF matches FreeBSD if_vtnet: one buffer per RX slot, header at
 * the start of the buffer, num_buffers for multi-slot frames.
 */
static struct virtio_feature netf[] = {
	{ "partial csum",	VIRTIO_NET_F_CSUM,	0,	1	},
	{ "guest csum",		VIRTIO_NET_F_GUEST_CSUM, 0,	1	},
	{ "given mac",		VIRTIO_NET_F_MAC,	0,	1	},
	{ "status",		VIRTIO_NET_F_STATUS,	0,	1	},
	{ "merge rx",		VIRTIO_NET_F_MRG_RXBUF,	0,	1	},
	{ "control channel",	VIRTIO_NET_F_CTRL_VQ,	0,	1	},
	{ "control channel rx",	VIRTIO_NET_F_CTRL_RX,	0,	1	},
	{ "ctrl rx extra",	VIRTIO_NET_F_CTRL_RX_EXTRA, 0,	1	},
	{ "control mac",	VIRTIO_NET_F_CTRL_MAC,	0,	1	},
	{ "guest announce",	VIRTIO_NET_F_GUEST_ANNOUNCE, 0,	1	}
};

static int
virtio_net_probe(unsigned int skip)
{
	int queues = 2;

	net_dev = virtio_mmio_setup(VIRTIO_DEV_NET, netdriver_name(), netf,
	    sizeof(netf) / sizeof(netf[0]), 1 /* threads */, skip);
	if (net_dev == NULL)
		return ENXIO;

	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_VQ))
		queues += 1;

	if (virtio_mmio_alloc_queues(net_dev, queues) != OK) {
		virtio_mmio_free(net_dev);
		return ENOMEM;
	}

	return OK;
}

static void
virtio_net_config(netdriver_addr_t * addr)
{
	int i;

	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_MAC)) {
		dprintf(("Mac set by host: "));
		for (i = 0; i < 6; i++)
			addr->na_addr[i] = virtio_mmio_config_read8(net_dev, i);

		for (i = 0; i < 6; i++)
			dprintf(("%02x%s", addr->na_addr[i],
					 i == 5 ? "\n" : ":"));
	} else {
		dput(("No mac"));
		/* Locally administered unicast fallback. */
		addr->na_addr[0] = 0x02;
		addr->na_addr[1] = 0x00;
		addr->na_addr[2] = 0x00;
		addr->na_addr[3] = 0x00;
		addr->na_addr[4] = 0x00;
		addr->na_addr[5] = 0x01;
	}

	memcpy(&hwaddr, addr, sizeof(hwaddr));

	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_STATUS)) {
		dput(("Current Status %x",
		    (u32_t)virtio_mmio_config_read16(net_dev, 6)));
	} else {
		dput(("No status"));
	}

	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_VQ))
		dput(("Host supports control channel"));

	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_RX))
		dput(("Host supports control channel for RX"));

	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_MRG_RXBUF))
		dput(("Host supports mergeable RX buffers"));
}

static unsigned int
virtio_net_get_link(uint32_t * media)
{
	u16_t status;

	*media = IFM_MAKEWORD(IFM_ETHER, IFM_AUTO, 0, 0);

	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_STATUS)) {
		status = virtio_mmio_config_read16(net_dev, 6);
		if (status & VIRTIO_NET_S_LINK_UP)
			return NDEV_LINK_UP;
		return NDEV_LINK_DOWN;
	}

	return NDEV_LINK_UP;
}

static uint32_t
cksum_add(uint32_t sum, const uint8_t * p, size_t len)
{

	while (len > 1) {
		sum += ((uint16_t)p[0] << 8) | p[1];
		p += 2;
		len -= 2;
	}
	if (len)
		sum += (uint16_t)p[0] << 8;
	return sum;
}

static uint16_t
cksum_fold_raw(uint32_t sum)
{

	while (sum >> 16)
		sum = (sum & 0xffff) + (sum >> 16);
	return (uint16_t)sum;
}

static uint16_t
cksum_fold(uint32_t sum)
{

	return ~cksum_fold_raw(sum);
}

static uint16_t
ether_type(const uint8_t * eth, size_t len, unsigned int * l3off)
{
	uint16_t etype;

	if (len < ETHER_HDR_LEN)
		return 0;
	etype = ((uint16_t)eth[12] << 8) | eth[13];
	*l3off = ETHER_HDR_LEN;
	if (etype == ETHERTYPE_VLAN) {
		if (len < ETHER_HDR_LEN + 4)
			return 0;
		etype = ((uint16_t)eth[16] << 8) | eth[17];
		*l3off = ETHER_HDR_LEN + 4;
	}
	return etype;
}

static void
put_be16(uint8_t * p, uint16_t v)
{

	p[0] = (uint8_t)(v >> 8);
	p[1] = (uint8_t)v;
}

/*
 * Fill virtio_net_hdr for TX checksum offload.  lwIP leaves the L4
 * checksum field as 0 when NDEV_CAP_CS_*_TX is enabled, so the driver
 * must install the uncomplemented pseudo-header sum (FreeBSD/Linux
 * CHECKSUM_PARTIAL) before setting NEEDS_CSUM.
 */
static void
virtio_net_tx_offload(struct packet * p, size_t len)
{
	struct virtio_net_hdr *hdr = p->vhdr;
	const uint8_t *eth = (const uint8_t *)p->vdata;
	const uint8_t *ip;
	unsigned int l3off, iphl, l4off, csum_off;
	uint16_t etype, l4len, pseudo;
	uint8_t proto;
	uint32_t sum;

	memset(hdr, 0, net_hdr_size);
	if (!(enabled_caps & (NDEV_CAP_CS_TCP_TX | NDEV_CAP_CS_UDP_TX)))
		return;

	etype = ether_type(eth, len, &l3off);
	if (etype == 0)
		return;
	ip = eth + l3off;

	if (etype == ETHERTYPE_IP) {
		if (len < l3off + 20)
			return;
		if ((ip[0] >> 4) != 4)
			return;
		iphl = (ip[0] & 0x0f) * 4;
		if (iphl < 20 || len < l3off + iphl)
			return;
		/* Skip fragments. */
		if (((((uint16_t)ip[6] & 0x1f) << 8) | ip[7]) != 0)
			return;
		proto = ip[9];
		l4off = l3off + iphl;
		if (len < l4off)
			return;
		l4len = (uint16_t)(len - l4off);
		sum = cksum_add(0, ip + 12, 8);
		sum += proto;
		sum += l4len;
	} else if (etype == ETHERTYPE_IPV6) {
		if (len < l3off + 40)
			return;
		if ((ip[0] >> 4) != 6)
			return;
		proto = ip[6];
		l4off = l3off + 40;
		if (len < l4off)
			return;
		l4len = (uint16_t)(len - l4off);
		sum = cksum_add(0, ip + 8, 32);
		sum += proto;
		sum += l4len;
	} else
		return;

	if (proto == IPPROTO_TCP &&
	    (enabled_caps & NDEV_CAP_CS_TCP_TX))
		csum_off = TCP_CSUM_OFF;
	else if (proto == IPPROTO_UDP &&
	    (enabled_caps & NDEV_CAP_CS_UDP_TX))
		csum_off = UDP_CSUM_OFF;
	else
		return;

	if (len < l4off + csum_off + 2)
		return;

	pseudo = cksum_fold_raw(sum);
	put_be16((uint8_t *)p->vdata + l4off + csum_off, pseudo);

	hdr->flags = VIRTIO_NET_HDR_F_NEEDS_CSUM;
	hdr->csum_start = (u16_t)l4off;
	hdr->csum_offset = (u16_t)csum_off;
}

static int
virtio_net_rx_fixup_csum(struct packet * p, size_t payload_len)
{
	struct virtio_net_hdr *hdr = p->vhdr;
	unsigned int start, off, csum_off;
	uint16_t csum;
	uint8_t *data;

	if (!(hdr->flags & VIRTIO_NET_HDR_F_NEEDS_CSUM))
		return OK;

	start = hdr->csum_start;
	off = hdr->csum_offset;
	csum_off = start + off;
	if ((size_t)csum_off + 2 > payload_len)
		return EINVAL;

	data = (uint8_t *)p->vdata;
	csum = cksum_fold(cksum_add(0, data + start,
	    payload_len - start));
	put_be16(data + csum_off, csum);
	hdr->flags &= (u8_t)~VIRTIO_NET_HDR_F_NEEDS_CSUM;
	hdr->flags |= VIRTIO_NET_HDR_F_DATA_VALID;
	return OK;
}

static int
virtio_net_ctrl_exec(struct vumap_phys * phys, int n)
{
	void *cookie;
	int i;

	ctrl_vir[CTRL_ACK_OFF] = 0xff;
	if (virtio_mmio_to_queue(net_dev, CTRL_Q, phys, n, ctrl_vir) != OK)
		return EIO;
	virtio_mmio_kick(net_dev, CTRL_Q);

	for (i = 0; i < CTRL_POLL_MAX; i++) {
		if (virtio_mmio_from_queue(net_dev, CTRL_Q, &cookie,
		    NULL) == 0) {
			if (ctrl_vir[CTRL_ACK_OFF] == VIRTIO_NET_OK)
				return OK;
			return EIO;
		}
	}
	return ETIMEDOUT;
}

static int
virtio_net_ctrl_rx_mode(uint8_t cmd, int enable)
{
	struct vumap_phys phys[3];
	struct virtio_net_ctrl_hdr *ch;

	ch = (struct virtio_net_ctrl_hdr *)(ctrl_vir + CTRL_HDR_OFF);
	ch->class = VIRTIO_NET_CTRL_RX;
	ch->cmd = cmd;
	ctrl_vir[CTRL_BYTE_OFF] = enable ? 1 : 0;

	phys[0].vp_addr = ctrl_phys + CTRL_HDR_OFF;
	phys[0].vp_size = sizeof(*ch);
	phys[1].vp_addr = ctrl_phys + CTRL_BYTE_OFF;
	phys[1].vp_size = 1;
	phys[2].vp_addr = (ctrl_phys + CTRL_ACK_OFF) | 1;
	phys[2].vp_size = 1;

	return virtio_net_ctrl_exec(phys, 3);
}

static int
virtio_net_ctrl_mac_table(const netdriver_addr_t * mcast_list,
	unsigned int mcast_count)
{
	struct vumap_phys phys[4];
	struct virtio_net_ctrl_hdr *ch;
	uint32_t *count;
	unsigned int i, n;

	if (mcast_list == NULL)
		mcast_count = 0;
	if (mcast_count > CTRL_MCAST_MAX)
		mcast_count = CTRL_MCAST_MAX;

	ch = (struct virtio_net_ctrl_hdr *)(ctrl_vir + CTRL_HDR_OFF);
	ch->class = VIRTIO_NET_CTRL_MAC;
	ch->cmd = VIRTIO_NET_CTRL_MAC_TABLE_SET;

	count = (uint32_t *)(ctrl_vir + CTRL_UNI_OFF);
	/* Primary MAC stays in device config / CTRL_MAC_ADDR_SET (#80). */
	*count = 0;

	count = (uint32_t *)(ctrl_vir + CTRL_MULTI_OFF);
	*count = mcast_count;
	for (i = 0, n = 0; i < mcast_count; i++, n += 6)
		memcpy(ctrl_vir + CTRL_MULTI_OFF + 4 + n,
		    mcast_list[i].na_addr, 6);

	phys[0].vp_addr = ctrl_phys + CTRL_HDR_OFF;
	phys[0].vp_size = sizeof(*ch);
	phys[1].vp_addr = ctrl_phys + CTRL_UNI_OFF;
	phys[1].vp_size = 4;
	phys[2].vp_addr = ctrl_phys + CTRL_MULTI_OFF;
	phys[2].vp_size = 4 + 6 * mcast_count;
	phys[3].vp_addr = (ctrl_phys + CTRL_ACK_OFF) | 1;
	phys[3].vp_size = 1;

	return virtio_net_ctrl_exec(phys, 4);
}

static int
virtio_net_ctrl_mac_addr(const netdriver_addr_t * addr)
{
	struct vumap_phys phys[3];
	struct virtio_net_ctrl_hdr *ch;

	ch = (struct virtio_net_ctrl_hdr *)(ctrl_vir + CTRL_HDR_OFF);
	ch->class = VIRTIO_NET_CTRL_MAC;
	ch->cmd = VIRTIO_NET_CTRL_MAC_ADDR_SET;
	memcpy(ctrl_vir + CTRL_MACADDR_OFF, addr->na_addr, 6);

	phys[0].vp_addr = ctrl_phys + CTRL_HDR_OFF;
	phys[0].vp_size = sizeof(*ch);
	phys[1].vp_addr = ctrl_phys + CTRL_MACADDR_OFF;
	phys[1].vp_size = 6;
	phys[2].vp_addr = (ctrl_phys + CTRL_ACK_OFF) | 1;
	phys[2].vp_size = 1;

	return virtio_net_ctrl_exec(phys, 3);
}

static int
virtio_net_ctrl_announce(void)
{
	struct vumap_phys phys[2];
	struct virtio_net_ctrl_hdr *ch;

	if (!have_announce || ctrl_vir == NULL)
		return OK;

	ch = (struct virtio_net_ctrl_hdr *)(ctrl_vir + CTRL_HDR_OFF);
	ch->class = VIRTIO_NET_CTRL_ANNOUNCE;
	ch->cmd = VIRTIO_NET_CTRL_ANNOUNCE_ACK;

	phys[0].vp_addr = ctrl_phys + CTRL_HDR_OFF;
	phys[0].vp_size = sizeof(*ch);
	phys[1].vp_addr = (ctrl_phys + CTRL_ACK_OFF) | 1;
	phys[1].vp_size = 1;

	return virtio_net_ctrl_exec(phys, 2);
}

static void
virtio_net_check_announce(void)
{
	u16_t status;
	int r;

	if (!have_announce)
		return;
	if (!virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_STATUS))
		return;

	status = virtio_mmio_config_read16(net_dev, 6);
	if (!(status & VIRTIO_NET_S_ANNOUNCE))
		return;

	r = virtio_net_ctrl_announce();
	if (r != OK)
		printf("%s: CTRL_ANNOUNCE ack failed (%d)\n",
		    netdriver_name(), r);
}

static void
virtio_net_set_caps(uint32_t caps)
{

	enabled_caps = caps;
}

static void
virtio_net_set_hwaddr(const netdriver_addr_t * addr)
{
	int r;

	memcpy(&hwaddr, addr, sizeof(hwaddr));
	if (!have_mac_ctrl || ctrl_vir == NULL)
		return;

	r = virtio_net_ctrl_mac_addr(addr);
	if (r != OK)
		printf("%s: CTRL_MAC addr failed (%d)\n",
		    netdriver_name(), r);
}

static void
virtio_net_set_mode(unsigned int mode,
	const netdriver_addr_t * mcast_list, unsigned int mcast_count)
{
	int r;

	if (!have_ctrl || mode == NDEV_MODE_DOWN)
		return;

	if (mcast_list == NULL)
		mcast_count = 0;
	r = virtio_net_ctrl_mac_table(mcast_list, mcast_count);
	if (r != OK)
		printf("%s: CTRL_MAC table failed (%d)\n",
		    netdriver_name(), r);

	r = virtio_net_ctrl_rx_mode(VIRTIO_NET_CTRL_RX_PROMISC,
	    (mode & NDEV_MODE_PROMISC) != 0);
	if (r != OK)
		printf("%s: CTRL_RX promisc failed (%d)\n",
		    netdriver_name(), r);

	r = virtio_net_ctrl_rx_mode(VIRTIO_NET_CTRL_RX_ALLMULTI,
	    (mode & NDEV_MODE_MCAST_ALL) != 0);
	if (r != OK)
		printf("%s: CTRL_RX allmulti failed (%d)\n",
		    netdriver_name(), r);

	if (have_rx_extra) {
		r = virtio_net_ctrl_rx_mode(VIRTIO_NET_CTRL_RX_NOBCAST,
		    (mode & (NDEV_MODE_BCAST | NDEV_MODE_PROMISC)) == 0);
		if (r != OK)
			printf("%s: CTRL_RX nobcast failed (%d)\n",
			    netdriver_name(), r);
	}
}

static int
virtio_net_alloc_bufs(void)
{

	data_vir = alloc_contig(PACKET_BUF_SZ, 0, &data_phys);

	if (!data_vir)
		return ENOMEM;

	packets = malloc(BUF_PACKETS * sizeof(packets[0]));

	if (!packets) {
		free_contig(data_vir, PACKET_BUF_SZ);
		return ENOMEM;
	}

	ctrl_vir = NULL;
	ctrl_phys = 0;
	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_VQ)) {
		ctrl_vir = alloc_contig(CTRL_MEM_SZ, 0, &ctrl_phys);
		if (ctrl_vir == NULL) {
			free(packets);
			free_contig(data_vir, PACKET_BUF_SZ);
			return ENOMEM;
		}
		memset(ctrl_vir, 0, CTRL_MEM_SZ);
	}

	memset(data_vir, 0, PACKET_BUF_SZ);
	memset(packets, 0, BUF_PACKETS * sizeof(packets[0]));

	return OK;
}

static void
virtio_net_init_queues(void)
{
	int i;

	STAILQ_INIT(&rx_free);
	STAILQ_INIT(&tx_free);
	STAILQ_INIT(&recv_list);

	for (i = 0; i < BUF_PACKETS; i++) {
		packets[i].idx = i;
		packets[i].vbuf = data_vir + i * pkt_slot_sz;
		packets[i].pbuf = data_phys + i * pkt_slot_sz;
		packets[i].vhdr = (struct virtio_net_hdr *)packets[i].vbuf;
		packets[i].vdata = packets[i].vbuf + net_hdr_size;
		if (i < RX_PACKETS)
			STAILQ_INSERT_HEAD(&rx_free, &packets[i], next);
		else
			STAILQ_INSERT_HEAD(&tx_free, &packets[i], next);
	}
}

static void
virtio_net_refill_rx_queue(void)
{
	struct vumap_phys phys[1];
	struct packet *p;
	int posted = 0;

	while (!STAILQ_EMPTY(&rx_free)) {
		p = STAILQ_FIRST(&rx_free);
		STAILQ_REMOVE_HEAD(&rx_free, next);

		phys[0].vp_addr = p->pbuf;
		assert(!(phys[0].vp_addr & 1));
		phys[0].vp_size = pkt_slot_sz;
		phys[0].vp_addr |= 1;

		if (virtio_mmio_to_queue(net_dev, RX_Q, phys, 1, p) != OK) {
			STAILQ_INSERT_HEAD(&rx_free, p, next);
			break;
		}
		in_rx++;
		posted++;
	}

	/*
	 * EVENT_IDX only notifies on the first posted slot.  Kick after
	 * the batch so QEMU sees all RX buffers, not just the first.
	 */
	if (posted)
		virtio_mmio_kick(net_dev, RX_Q);

	if (in_rx == 0 && STAILQ_EMPTY(&rx_free))
		dput(("warning: rx queue underflow!"));
}

static void
virtio_net_check_queues(void)
{
	struct packet *p;
	size_t len;

	/*
	 * Drain, then enable_cb (publish used_event = last_used) and
	 * drain again if the device added buffers during the barrier.
	 * from_queue no longer pokes used_event on each consume.
	 */
	for (;;) {
		while (virtio_mmio_from_queue(net_dev, RX_Q,
		    (void **)&p, &len) == 0) {
			p->len = len;
			STAILQ_INSERT_TAIL(&recv_list, p, next);
			in_rx--;
		}
		if (!virtio_mmio_enable_cb(net_dev, RX_Q))
			break;
	}

	for (;;) {
		while (virtio_mmio_from_queue(net_dev, TX_Q,
		    (void **)&p, NULL) == 0) {
			memset(p->vbuf, 0, pkt_slot_sz);
			STAILQ_INSERT_HEAD(&tx_free, p, next);
		}
		if (!virtio_mmio_enable_cb(net_dev, TX_Q))
			break;
	}
}

static void
virtio_net_poll(void)
{

	virtio_net_check_queues();
	virtio_net_refill_rx_queue();
}

static void
virtio_net_tick(void)
{

	virtio_net_poll();
	virtio_net_check_pending();
}

static void
virtio_net_check_pending(void)
{

	if (!STAILQ_EMPTY(&recv_list))
		netdriver_recv();

	if (!STAILQ_EMPTY(&tx_free))
		netdriver_send();
}

static void
virtio_net_intr(unsigned int __unused mask)
{
	int status;

	status = virtio_mmio_had_irq(net_dev);
	if (status & VIRTIO_MMIO_INT_CONFIG) {
		virtio_net_check_announce();
		netdriver_link();
	} else if (!status) {
		if (!spurious_interrupt)
			dput(("Spurious interrupt"));

		spurious_interrupt = 1;
	}

	/* Always drain: ISR may be 0 if we already polled after TX. */
	virtio_net_poll();
	virtio_net_check_pending();

	virtio_mmio_irq_enable(net_dev);
}

static int
virtio_net_send(struct netdriver_data * data, size_t len)
{
	struct vumap_phys phys[1];
	struct packet *p;

	if (STAILQ_EMPTY(&tx_free))
		return SUSPEND;

	p = STAILQ_FIRST(&tx_free);
	STAILQ_REMOVE_HEAD(&tx_free, next);

	if (len > MAX_PACK_SIZE)
		panic("%s: packet too large to send: %zu",
		    netdriver_name(), len);

	netdriver_copyin(data, 0, p->vdata, len);
	virtio_net_tx_offload(p, len);

	phys[0].vp_addr = p->pbuf;
	assert(!(phys[0].vp_addr & 1));
	phys[0].vp_size = net_hdr_size + len;
	virtio_mmio_to_queue(net_dev, TX_Q, phys, 1, p);
	virtio_mmio_kick(net_dev, TX_Q);
	/*
	 * QEMU slirp replies during the TX QUEUE_NOTIFY MMIO.  virtio-blk
	 * busy-waits on from_queue; drain RX here so ping does not depend
	 * on the used-ring IRQ surviving EVENT_IDX.  Do not call
	 * netdriver_send: we are already inside ndr_send.
	 */
	virtio_net_poll();
	if (!STAILQ_EMPTY(&recv_list))
		netdriver_recv();

	return OK;
}

static void
virtio_net_recycle_rx(struct packet *p)
{

	memset(p->vbuf, 0, pkt_slot_sz);
	STAILQ_INSERT_HEAD(&rx_free, p, next);
}

/*
 * FreeBSD if_vtnet mergeable RX: num_buffers counts consecutive used
 * buffers.  Only the first carries virtio_net_hdr; the rest are payload.
 */
static int
virtio_net_merge_rx(struct packet *p, size_t *payload_len)
{
	struct virtio_net_hdr_mrg_rxbuf *mh;
	unsigned int nbuf, i;
	size_t len = *payload_len;

	if (!have_mrg)
		return OK;

	mh = (struct virtio_net_hdr_mrg_rxbuf *)p->vhdr;
	nbuf = mh->num_buffers;
	if (nbuf <= 1)
		return OK;

	for (i = 1; i < nbuf; i++) {
		struct packet *extra;
		size_t elen;

		if (STAILQ_EMPTY(&recv_list))
			return EINVAL;
		extra = STAILQ_FIRST(&recv_list);
		STAILQ_REMOVE_HEAD(&recv_list, next);
		elen = extra->len;
		if (len + elen > MAX_PACK_SIZE) {
			virtio_net_recycle_rx(extra);
			return EINVAL;
		}
		memcpy(p->vdata + len, extra->vbuf, elen);
		len += elen;
		virtio_net_recycle_rx(extra);
	}
	*payload_len = len;
	return OK;
}

static ssize_t
virtio_net_recv(struct netdriver_data * data, size_t max)
{
	struct packet *p;
	ssize_t len;
	size_t payload;

	for (;;) {
		if (STAILQ_EMPTY(&recv_list)) {
			virtio_net_check_queues();
			if (STAILQ_EMPTY(&recv_list))
				return SUSPEND;
		}

		p = STAILQ_FIRST(&recv_list);
		STAILQ_REMOVE_HEAD(&recv_list, next);

		if (p->len < net_hdr_size) {
			netdriver_stat_ierror(1);
			virtio_net_recycle_rx(p);
			virtio_net_refill_rx_queue();
			continue;
		}
		payload = p->len - net_hdr_size;
		if (virtio_net_merge_rx(p, &payload) != OK) {
			netdriver_stat_ierror(1);
			virtio_net_recycle_rx(p);
			virtio_net_refill_rx_queue();
			continue;
		}
		if (payload > max)
			payload = max;
		len = (ssize_t)payload;

		if (virtio_net_rx_fixup_csum(p, (size_t)len) != OK) {
			netdriver_stat_ierror(1);
			virtio_net_recycle_rx(p);
			virtio_net_refill_rx_queue();
			continue;
		}
		break;
	}

	/*
	 * HACK: due to lack of padding, received packets may in fact be
	 * smaller than the minimum ethernet packet size.  The TCP/IP service
	 * will accept the packets just fine if we increase the length to its
	 * minimum.  We already zeroed out the rest of the packet data, so this
	 * is safe.
	 */
	if (len < NDEV_ETH_PACKET_MIN)
		len = NDEV_ETH_PACKET_MIN;

	netdriver_copyout(data, 0, p->vdata, len);

	virtio_net_recycle_rx(p);

	virtio_net_refill_rx_queue();

	return len;
}

static int
virtio_net_init(unsigned int instance, netdriver_addr_t * addr,
	uint32_t * caps, unsigned int * ticks)
{
	int r;

	if ((r = virtio_net_probe(instance)) != OK)
		return r;

	if (virtio_mmio_version(net_dev) >= 2 ||
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_MRG_RXBUF))
		net_hdr_size = VIRTIO_NET_HDR_SIZE_MODERN;
	else
		net_hdr_size = VIRTIO_NET_HDR_SIZE_LEGACY;

	pkt_slot_sz = net_hdr_size + MAX_PACK_SIZE;
	have_mrg = virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_MRG_RXBUF);
	have_ctrl = virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_VQ) &&
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_RX);
	have_rx_extra = have_ctrl &&
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_RX_EXTRA);
	have_mac_ctrl =
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_VQ) &&
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_MAC);
	have_announce =
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_VQ) &&
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_GUEST_ANNOUNCE);

	virtio_net_config(addr);

	if (virtio_net_alloc_bufs() != OK)
		panic("%s: Buffer allocation failed", netdriver_name());

	if (have_ctrl && ctrl_vir == NULL)
		have_ctrl = 0;
	if (have_rx_extra && !have_ctrl)
		have_rx_extra = 0;
	if (have_mac_ctrl && ctrl_vir == NULL)
		have_mac_ctrl = 0;
	if (have_announce && ctrl_vir == NULL)
		have_announce = 0;

	virtio_net_init_queues();

	/*
	 * Mark the device DRIVER_OK before posting RX buffers.  QEMU's
	 * virtio-mmio transport ignores queue notifies until DRIVER_OK, so
	 * a pre-ready refill can leave the RX ring silent and drop replies.
	 */
	virtio_mmio_device_ready(net_dev);

	virtio_net_refill_rx_queue();
	(void)virtio_mmio_enable_cb(net_dev, RX_Q);

	printf("virtio-net-mmio: initialized\n");
	printf("virtio-net-mmio: mac %02x:%02x:%02x:%02x:%02x:%02x\n",
	    addr->na_addr[0], addr->na_addr[1], addr->na_addr[2],
	    addr->na_addr[3], addr->na_addr[4], addr->na_addr[5]);
	printf("virtio-net-mmio: hdr %zu csum %s ctrl_rx %s mrg %s event_idx %s rx %u tx %u\n",
	    net_hdr_size,
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CSUM) ?
		"on" : "off",
	    have_ctrl ? "on" : "off",
	    have_mrg ? "on" : "off",
	    virtio_mmio_has_event_idx(net_dev) ? "on" : "off",
	    (unsigned int)RX_PACKETS, (unsigned int)TX_PACKETS);

	*caps = NDEV_CAP_MCAST | NDEV_CAP_BCAST;
	if (have_mac_ctrl)
		*caps |= NDEV_CAP_HWADDR;
	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CSUM))
		*caps |= NDEV_CAP_CS_TCP_TX | NDEV_CAP_CS_UDP_TX;
	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_GUEST_CSUM))
		*caps |= NDEV_CAP_CS_TCP_RX | NDEV_CAP_CS_UDP_RX;
	*ticks = sys_hz() / 10;
	if (*ticks == 0)
		*ticks = 1;
	return OK;
}

static void
virtio_net_stop(void)
{

	dput(("Terminating"));

	free_contig(data_vir, PACKET_BUF_SZ);
	if (ctrl_vir != NULL)
		free_contig(ctrl_vir, CTRL_MEM_SZ);
	free(packets);

	virtio_mmio_reset(net_dev);
	virtio_mmio_free_queues(net_dev);
	virtio_mmio_free(net_dev);
	net_dev = NULL;
}

int
main(int argc, char *argv[])
{

	env_setargs(argc, argv);

	netdriver_task(&virtio_net_table);

	return 0;
}
