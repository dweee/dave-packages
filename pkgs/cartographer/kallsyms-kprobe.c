#include <linux/errno.h>
#include <linux/kprobes.h>

#include "kallsyms.h"

static unsigned long (*kallsyms_lookup_name_fn)(const char *name);

unsigned long kallsyms_lookup_name(const char *name)
{
	if (!kallsyms_lookup_name_fn)
		return 0;
	return kallsyms_lookup_name_fn(name);
}

int init_kallsyms(void)
{
	struct kprobe kp = {
		.symbol_name = "kallsyms_lookup_name",
	};
	int ret;

	ret = register_kprobe(&kp);
	if (ret < 0)
		return ret;

	kallsyms_lookup_name_fn = (void *)kp.addr;
	unregister_kprobe(&kp);

	return kallsyms_lookup_name_fn ? 0 : -ENOENT;
}
