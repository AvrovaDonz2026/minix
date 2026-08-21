/* virtio net driver for MINIX 3 (MMIO / RISC-V)
 *
 * Copyright (c) 2013, A. Welzel, <arne.welzel@gmail.com>
 *
 * Datapath follows FreeBSD if_vtnet: modern virtio_net_hdr (12 bytes
 * when VIRTIO_F_VERSION_1), TX partial checksum, RX NEEDS_CSUM fixup,
 * CTRL_VQ RX filter, and config-change link status.
 *
 * This software is released under the BSD license. See the LICENSE file
 * included in the main directory of this source distribution for the
 * license terms and conditions.
 */

#include <assert.h>
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

#define RX_PACKETS		32
#define TX_PACKETS		32
#define BUF_PACKETS		(RX_PACKETS + TX_PACKETS)
#define MAX_PACK_SIZE		NDEV_ETH_PACKET_MAX
#define PACKET_BUF_SZ		(BUF_PACKETS * MAX_PACK_SIZE)

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
#define CTRL_UNI_OFF		16
#define CTRL_MULTI_OFF		32
#define CTRL_MCAST_MAX		16
#define CTRL_POLL_MAX		10000

struct packet {
	int idx;
	struct virtio_net_hdr *vhdr;
	phys_bytes phdr;
	char *vdata;
	phys_bytes pdata;
	size_t len;
	STAILQ_ENTRY(packet) next;
};

static char *data_vir;
static phys_bytes data_phys;
static struct virtio_net_hdr_mrg_rxbuf *hdrs_vir;
static phys_bytes hdrs_phys;
static struct packet *packets;
static int in_rx;
static size_t net_hdr_size;
static uint32_t enabled_caps;
static netdriver_addr_t hwaddr;
static uint8_t *ctrl_vir;
static phys_bytes ctrl_phys;
static int have_ctrl;

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
static void virtio_net_set_mode(unsigned int mode,
	const netdriver_addr_t * mcast_list, unsigned int mcast_count);
static void virtio_net_set_caps(uint32_t caps);

static const struct netdriver virtio_net_table = {
	.ndr_name	= "vio",
	.ndr_init	= virtio_net_init,
	.ndr_stop	= virtio_net_stop,
	.ndr_set_mode	= virtio_net_set_mode,
	.ndr_set_caps	= virtio_net_set_caps,
	.ndr_recv	= virtio_net_recv,
	.ndr_send	= virtio_net_send,
	.ndr_get_link	= virtio_net_get_link,
	.ndr_intr	= virtio_net_intr,
};

/*
 * Guest bits are offers; host_supports() after setup is the negotiated set.
 * Do not offer MRG_RXBUF: we post one full-frame buffer per RX slot.
 */
static struct virtio_feature netf[] = {
	{ "partial csum",	VIRTIO_NET_F_CSUM,	0,	1	},
	{ "guest csum",		VIRTIO_NET_F_GUEST_CSUM, 0,	1	},
	{ "given mac",		VIRTIO_NET_F_MAC,	0,	1	},
	{ "status",		VIRTIO_NET_F_STATUS,	0,	1	},
	{ "control channel",	VIRTIO_NET_F_CTRL_VQ,	0,	1	},
	{ "control channel rx",	VIRTIO_NET_F_CTRL_RX,	0,	1	}
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
	u32_t mac14;
	u32_t mac56;
	int i;

	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_MAC)) {
		dprintf(("Mac set by host: "));
		mac14 = virtio_mmio_config_read32(net_dev, 0);
		mac56 = virtio_mmio_config_read32(net_dev, 4);
		memcpy(&addr->na_addr[0], &mac14, 4);
		memcpy(&addr->na_addr[4], &mac56, 2);

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

	if (mcast_count > CTRL_MCAST_MAX)
		mcast_count = CTRL_MCAST_MAX;

	ch = (struct virtio_net_ctrl_hdr *)(ctrl_vir + CTRL_HDR_OFF);
	ch->class = VIRTIO_NET_CTRL_MAC;
	ch->cmd = VIRTIO_NET_CTRL_MAC_TABLE_SET;

	count = (uint32_t *)(ctrl_vir + CTRL_UNI_OFF);
	*count = 1;
	memcpy(ctrl_vir + CTRL_UNI_OFF + 4, hwaddr.na_addr, 6);

	count = (uint32_t *)(ctrl_vir + CTRL_MULTI_OFF);
	*count = mcast_count;
	for (i = 0, n = 0; i < mcast_count; i++, n += 6)
		memcpy(ctrl_vir + CTRL_MULTI_OFF + 4 + n,
		    mcast_list[i].na_addr, 6);

	phys[0].vp_addr = ctrl_phys + CTRL_HDR_OFF;
	phys[0].vp_size = sizeof(*ch);
	phys[1].vp_addr = ctrl_phys + CTRL_UNI_OFF;
	phys[1].vp_size = 4 + 6;
	phys[2].vp_addr = ctrl_phys + CTRL_MULTI_OFF;
	phys[2].vp_size = 4 + 6 * mcast_count;
	phys[3].vp_addr = (ctrl_phys + CTRL_ACK_OFF) | 1;
	phys[3].vp_size = 1;

	return virtio_net_ctrl_exec(phys, 4);
}

static void
virtio_net_set_caps(uint32_t caps)
{

	enabled_caps = caps;
}

static void
virtio_net_set_mode(unsigned int mode,
	const netdriver_addr_t * mcast_list, unsigned int mcast_count)
{
	int r;

	if (!have_ctrl || mode == NDEV_MODE_DOWN)
		return;

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

	if (mcast_list == NULL)
		mcast_count = 0;
	r = virtio_net_ctrl_mac_table(mcast_list, mcast_count);
	if (r != OK)
		printf("%s: CTRL_MAC table failed (%d)\n",
		    netdriver_name(), r);
}

static int
virtio_net_alloc_bufs(void)
{
	data_vir = alloc_contig(PACKET_BUF_SZ, 0, &data_phys);

	if (!data_vir)
		return ENOMEM;

	hdrs_vir = alloc_contig(BUF_PACKETS * sizeof(hdrs_vir[0]),
				 0, &hdrs_phys);

	if (!hdrs_vir) {
		free_contig(data_vir, PACKET_BUF_SZ);
		return ENOMEM;
	}

	packets = malloc(BUF_PACKETS * sizeof(packets[0]));

	if (!packets) {
		free_contig(data_vir, PACKET_BUF_SZ);
		free_contig(hdrs_vir, BUF_PACKETS * sizeof(hdrs_vir[0]));
		return ENOMEM;
	}

	ctrl_vir = NULL;
	ctrl_phys = 0;
	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_VQ)) {
		ctrl_vir = alloc_contig(CTRL_MEM_SZ, 0, &ctrl_phys);
		if (ctrl_vir == NULL) {
			free(packets);
			free_contig(data_vir, PACKET_BUF_SZ);
			free_contig(hdrs_vir,
			    BUF_PACKETS * sizeof(hdrs_vir[0]));
			return ENOMEM;
		}
		memset(ctrl_vir, 0, CTRL_MEM_SZ);
	}

	memset(data_vir, 0, PACKET_BUF_SZ);
	memset(hdrs_vir, 0, BUF_PACKETS * sizeof(hdrs_vir[0]));
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
		packets[i].vhdr = &hdrs_vir[i].hdr;
		packets[i].phdr = hdrs_phys + i * sizeof(hdrs_vir[i]);
		packets[i].vdata = data_vir + i * MAX_PACK_SIZE;
		packets[i].pdata = data_phys + i * MAX_PACK_SIZE;
		if (i < RX_PACKETS)
			STAILQ_INSERT_HEAD(&rx_free, &packets[i], next);
		else
			STAILQ_INSERT_HEAD(&tx_free, &packets[i], next);
	}
}

static void
virtio_net_refill_rx_queue(void)
{
	struct vumap_phys phys[2];
	struct packet *p;

	while (!STAILQ_EMPTY(&rx_free)) {
		p = STAILQ_FIRST(&rx_free);
		STAILQ_REMOVE_HEAD(&rx_free, next);

		phys[0].vp_addr = p->phdr;
		assert(!(phys[0].vp_addr & 1));
		phys[0].vp_size = net_hdr_size;

		phys[1].vp_addr = p->pdata;
		assert(!(phys[1].vp_addr & 1));
		phys[1].vp_size = MAX_PACK_SIZE;

		/* RX queue needs write */
		phys[0].vp_addr |= 1;
		phys[1].vp_addr |= 1;

		if (virtio_mmio_to_queue(net_dev, RX_Q, phys, 2, p) != OK) {
			STAILQ_INSERT_HEAD(&rx_free, p, next);
			break;
		}
		in_rx++;
	}

	if (in_rx == 0 && STAILQ_EMPTY(&rx_free))
		dput(("warning: rx queue underflow!"));
}

static void
virtio_net_check_queues(void)
{
	struct packet *p;
	size_t len;

	while (virtio_mmio_from_queue(net_dev, RX_Q, (void **)&p, &len) == 0) {
		p->len = len;
		STAILQ_INSERT_TAIL(&recv_list, p, next);
		in_rx--;
	}

	while (virtio_mmio_from_queue(net_dev, TX_Q, (void **)&p, NULL) == 0) {
		memset(p->vhdr, 0, net_hdr_size);
		STAILQ_INSERT_HEAD(&tx_free, p, next);
	}
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
	if (status) {
		if (status & VIRTIO_MMIO_INT_CONFIG)
			netdriver_link();
		if (status & VIRTIO_MMIO_INT_VRING)
			virtio_net_check_queues();
	} else {
		if (!spurious_interrupt)
			dput(("Spurious interrupt"));

		spurious_interrupt = 1;
	}

	virtio_net_check_pending();

	virtio_mmio_irq_enable(net_dev);

	virtio_net_refill_rx_queue();
}

static int
virtio_net_send(struct netdriver_data * data, size_t len)
{
	struct vumap_phys phys[2];
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

	phys[0].vp_addr = p->phdr;
	assert(!(phys[0].vp_addr & 1));
	phys[0].vp_size = net_hdr_size;
	phys[1].vp_addr = p->pdata;
	assert(!(phys[1].vp_addr & 1));
	phys[1].vp_size = len;
	virtio_mmio_to_queue(net_dev, TX_Q, phys, 2, p);

	return OK;
}

static ssize_t
virtio_net_recv(struct netdriver_data * data, size_t max)
{
	struct packet *p;
	ssize_t len;

	for (;;) {
		if (STAILQ_EMPTY(&recv_list))
			return SUSPEND;

		p = STAILQ_FIRST(&recv_list);
		STAILQ_REMOVE_HEAD(&recv_list, next);

		if (p->len < net_hdr_size)
			panic("received packet does not have virtio header");
		len = p->len - net_hdr_size;
		if ((size_t)len > max)
			len = (ssize_t)max;

		if (virtio_net_rx_fixup_csum(p, (size_t)len) != OK) {
			netdriver_stat_ierror(1);
			memset(p->vhdr, 0, net_hdr_size);
			memset(p->vdata, 0, MAX_PACK_SIZE);
			STAILQ_INSERT_HEAD(&rx_free, p, next);
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

	memset(p->vhdr, 0, net_hdr_size);
	memset(p->vdata, 0, MAX_PACK_SIZE);
	STAILQ_INSERT_HEAD(&rx_free, p, next);

	virtio_net_refill_rx_queue();

	return len;
}

static int
virtio_net_init(unsigned int instance, netdriver_addr_t * addr,
	uint32_t * caps, unsigned int * ticks __unused)
{
	int r;

	if ((r = virtio_net_probe(instance)) != OK)
		return r;

	if (virtio_mmio_version(net_dev) >= 2 ||
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_MRG_RXBUF))
		net_hdr_size = VIRTIO_NET_HDR_SIZE_MODERN;
	else
		net_hdr_size = VIRTIO_NET_HDR_SIZE_LEGACY;

	have_ctrl = virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_VQ) &&
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CTRL_RX);

	virtio_net_config(addr);

	if (virtio_net_alloc_bufs() != OK)
		panic("%s: Buffer allocation failed", netdriver_name());

	if (have_ctrl && ctrl_vir == NULL)
		have_ctrl = 0;

	virtio_net_init_queues();

	/*
	 * Mark the device DRIVER_OK before posting RX buffers.  QEMU's
	 * virtio-mmio transport ignores queue notifies until DRIVER_OK, so
	 * a pre-ready refill can leave the RX ring silent and drop replies.
	 */
	virtio_mmio_device_ready(net_dev);

	virtio_net_refill_rx_queue();

	printf("virtio-net-mmio: initialized\n");
	printf("virtio-net-mmio: hdr %zu csum %s ctrl_rx %s\n",
	    net_hdr_size,
	    virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CSUM) ?
		"on" : "off",
	    have_ctrl ? "on" : "off");

	*caps = NDEV_CAP_MCAST | NDEV_CAP_BCAST;
	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_CSUM))
		*caps |= NDEV_CAP_CS_TCP_TX | NDEV_CAP_CS_UDP_TX;
	if (virtio_mmio_host_supports(net_dev, VIRTIO_NET_F_GUEST_CSUM))
		*caps |= NDEV_CAP_CS_TCP_RX | NDEV_CAP_CS_UDP_RX;
	return OK;
}

static void
virtio_net_stop(void)
{

	dput(("Terminating"));

	free_contig(data_vir, PACKET_BUF_SZ);
	free_contig(hdrs_vir, BUF_PACKETS * sizeof(hdrs_vir[0]));
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
