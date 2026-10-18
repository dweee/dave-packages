/* Keep both functions visible for the headless Ghidra integration check. */
__attribute__((noinline)) unsigned int kuna_probe(unsigned int value) {
    return value * 7U + 3U;
}

__attribute__((noinline)) unsigned int kuna_constant(void) {
    return 0x4b554e41U;
}

int main(void) {
    return kuna_probe(5U) == 38U && kuna_constant() == 0x4b554e41U ? 0 : 1;
}
