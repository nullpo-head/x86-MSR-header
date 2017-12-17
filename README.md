# x86 MSR header

A Public-domain C header file for x86 MSR (Model Specific Register) addresses, and a naive generator of it.

I was looking for non-GPL headers for MSR definition, but eventually I could not find one. So I made it.
Since `msr.h` is in the public domain, you can use it freely.

This repository contains

1. Public-domain C header file for x86 MSR (Model Specific Register) addresses (`msr.h`)

2. The BSD-licensed generator script of the header. (`extract_msr.rb`)

`msr.h` is automatically generated from "Intel 64 and IA-32 Architectures Software Developer Manuals" (September 2016),
by `extract_msr.rb`. So, it may contain incorrect definitions. Please report it if you find one.

For the usage of `extract_msr.rb`, plaese read its help.
