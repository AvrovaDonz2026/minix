/*
 * Host-runnable unit test for virtio EVENT_IDX notify math (bugs #73, #74).
 */

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef uint8_t u8_t;
typedef uint16_t u16_t;
typedef uint32_t u32_t;
typedef uint64_t u64_t;

#include "../../lib/libvirtio_mmio/virtio_ring.h"
#include "../../drivers/net/virtio_net/virtio_net.h"

static int failures;

static void
check_int(const char *name, int got, int expected)
{
	if (got == expected)
		printf("ok: %s\n", name);
	else {
		printf("FAIL: %s expected %d got %d\n", name, expected, got);
		failures++;
	}
}

static int
qemu_used_notify(u16_t used_event, u16_t new_idx, u16_t *signalled_used,
    int *signalled_used_valid)
{
	if (!*signalled_used_valid) {
		*signalled_used = new_idx;
		*signalled_used_valid = 1;
		return 1;
	}
	if (vring_need_event(used_event, new_idx, *signalled_used)) {
		*signalled_used = new_idx;
		return 1;
	}
	return 0;
}

static int
enable_cb_recheck(u16_t last_used, u16_t used_idx)
{

	return last_used != used_idx;
}

static void
test_avail_kick(void)
{
	int kicks;
	u16_t old;
	int i;

	check_int("avail_kick_first_buffer",
	    vring_need_event(0, 1, 0), 1);
	check_int("avail_kick_second_buffer",
	    vring_need_event(0, 2, 1), 0);

	kicks = 0;
	old = 0;
	for (i = 1; i <= 256; i++) {
		if (vring_need_event(0, (u16_t)i, old))
			kicks++;
		old = (u16_t)i;
	}
	check_int("avail_kick_256_slot_rx_refill", kicks, 1);
}

static void
test_used_ring_silent_rx(void)
{
	u16_t used_event;
	u16_t signalled_used;
	int signalled_used_valid;
	int notify;

	used_event = 0;
	signalled_used = 0;
	signalled_used_valid = 0;

	notify = qemu_used_notify(used_event, 1, &signalled_used,
	    &signalled_used_valid);
	check_int("used_ring_ipv6_ra_first_notify", notify, 1);
	check_int("used_ring_ipv6_ra_signalled_used", signalled_used, 1);

	notify = qemu_used_notify(used_event, 2, &signalled_used,
	    &signalled_used_valid);
	check_int("used_ring_icmp_reply_suppressed", notify, 0);

	check_int("used_ring_need_event_suppressed",
	    vring_need_event(0, 2, 1), 0);
	check_int("used_ring_need_event_after_enable_cb",
	    vring_need_event(1, 2, 1), 1);

	used_event = 1;
	notify = qemu_used_notify(used_event, 2, &signalled_used,
	    &signalled_used_valid);
	check_int("used_ring_after_enable_cb_notify", notify, 1);
}

static void
test_enable_cb_recheck(void)
{

	check_int("enable_cb_drain_again_partial",
	    enable_cb_recheck(1, 2), 1);
	check_int("enable_cb_no_extra_drain",
	    enable_cb_recheck(2, 2), 0);
}

static void
test_header_layout(void)
{

	check_int("header_mrg_rxbuf_size",
	    (int)sizeof(struct virtio_net_hdr_mrg_rxbuf), 12);
	check_int("header_legacy_size",
	    (int)sizeof(struct virtio_net_hdr), 10);
	check_int("header_num_buffers_offset",
	    (int)offsetof(struct virtio_net_hdr_mrg_rxbuf, num_buffers), 10);
}

static void
test_wrap_around(void)
{

	check_int("wrap_around_first_slot_after_wrap",
	    vring_need_event(65535, 0, 65535), 1);
}

int
main(void)
{

	failures = 0;

	test_avail_kick();
	test_used_ring_silent_rx();
	test_enable_cb_recheck();
	test_header_layout();
	test_wrap_around();

	if (failures == 0) {
		printf("PASS: virtio EVENT_IDX\n");
		return 0;
	}

	printf("FAIL: virtio EVENT_IDX (%d check(s) failed)\n", failures);
	return 1;
}
