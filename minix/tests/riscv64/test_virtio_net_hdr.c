/*
 * Compile-time layout checks for virtio-net headers.
 *
 * VirtIO 1.0 (VIRTIO_F_VERSION_1) and FreeBSD if_vtnet use a 12-byte
 * modern header that includes num_buffers.  A 10-byte RX descriptor
 * on QEMU virtio-mmio shifts the ethernet frame by two bytes.
 */

#include <stdint.h>

typedef uint8_t u8_t;
typedef uint16_t u16_t;
typedef uint32_t u32_t;

#include "../../drivers/net/virtio_net/virtio_net.h"

/* Division by zero if the on-wire sizes drift. */
enum {
	VTNET_HDR_LEGACY_OK =
	    1 / (sizeof(struct virtio_net_hdr) == 10),
	VTNET_HDR_MODERN_OK =
	    1 / (sizeof(struct virtio_net_hdr_mrg_rxbuf) == 12)
};

int
virtio_net_hdr_layout_ok(void)
{

	return VTNET_HDR_LEGACY_OK && VTNET_HDR_MODERN_OK &&
	    VIRTIO_NET_HDR_SIZE_LEGACY == 10 &&
	    VIRTIO_NET_HDR_SIZE_MODERN == 12;
}
