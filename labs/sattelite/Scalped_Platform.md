Scalpel Platform — U-Boot / I2C EEPROM Forensics Writeup
Challenge description
The target exposes a broken satellite On-Board Computer through U-Boot.
The system cannot boot because the normal storage devices are unavailable, but the challenge hints that traces of the previous configuration may still exist:
A satellite On-Board Computer (OBC) was recovered from a damaged flatsat,
but critical components are missing and the system can no longer complete
its boot sequence.

While the hardware appears unusable, traces of its previous configuration
may still remain.

The goal is therefore to inspect the remaining low-level hardware through U-Boot and recover the abandoned configuration.
1. Connect to the target
nc <IP> <PORT>

Example:
nc 154.57.164.69 32121

The system drops into a U-Boot shell:
U-Boot 2026.04-rc5-00011-gc24a72c35abe

DRAM:  512 MiB
Flash: 64 MiB

Loading Environment from EEPROM...
*** Warning - EEPROM erased, fallback to other I2C bus

Loading Environment from EEPROM...
*** Warning - bad CRC, using default environment

No bootflows found
=>

The important part is:
EEPROM erased
fallback to other I2C bus
bad CRC, using default environment

This suggests that U-Boot normally loads its environment from EEPROM, but the stored environment is corrupted or missing.
2. Enumerate available U-Boot commands
help

Relevant commands include:
env
i2c
md
printenv
saveenv
setenv

Since the challenge mentions configuration traces, printenv is a logical first step.
3. Inspect the current environment
printenv

Relevant output:
arch=arm
board=flat-cubesat-obc1
cpu=XC7Z010
env_offset=0x800
vendor=SpaceAgency

The most important value is:
env_offset=0x800

This tells us where the U-Boot environment is expected inside the EEPROM.
However, the boot message already told us that the currently loaded environment is only the default environment, because the stored one failed CRC validation.
So we need to inspect the EEPROM manually.
4. Enumerate the I2C buses
First inspect the I2C subsystem:
i2c

Useful subcommands include:
i2c bus
i2c dev
i2c probe
i2c md

List the buses:
i2c bus

Output:
Bus 0: I2C bus 0
Bus 1: I2C bus 1

Probe bus 0:
i2c dev 0
i2c probe

Output:
Valid chip addresses: 18 50

Probe bus 1:
i2c dev 1
i2c probe

Output:
Valid chip addresses: 18 50 68

The device at 0x50 is a strong EEPROM candidate.
5. Inspect EEPROM at the U-Boot environment offset
Bus 0
i2c dev 0
i2c md 50 800 40

Output:
0800: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff
0810: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff
0820: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff
0830: ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff

Bus 0 is erased at this offset.
Bus 1
i2c dev 1
i2c md 50 800 100

Output contains readable ASCII:
0800: 00 54 06 1f 61 72 63 68 3d 63 68 61 6e 67 65 64
0810: 00 62 61 75 64 72 61 74 65 3d 31 31 35 32 30 30
...
0890: 63 72 79 70 74 65 64 5f 66 6c 61 67 3d 31 37 33
...

Decoded, this contains environment variables such as:
arch=changed
baudrate=115200
board=flat-cubesat-obc1
boot_targets=mmc1
...
encrypted_flag=1730224ef5f5848908754f2cbea80f9782e30aea053f41b599a937e2778a4d8d
...
vendor=emulation

So the second EEPROM still contains the old U-Boot environment.
The important recovered value is:
encrypted_flag=1730224ef5f5848908754f2cbea80f9782e30aea053f41b599a937e2778a4d8d

6. Look for the encryption material
The flag is encrypted, so we need the corresponding key and IV.
The environment starts at:
0x800

So another useful place to inspect is elsewhere in the EEPROM.
Switch back to bus 0 and read from offset 0x100, using a 2-byte offset:
i2c dev 0
i2c md 50 100.2 100

Output:
0100: 41 45 53 5f 4b 45 59 3d 62 35 65 30 30 65 37 61
0110: 37 38 35 63 66 66 62 66 65 64 30 64 34 30 32 33
0120: 65 33 62 63 33 62 35 65 64 65 35 31 34 65 62 38
0130: 36 36 35 34 38 32 65 39 61 36 31 32 32 31 65 61
0140: 39 31 38 34 64 65 64 30 0a 49 56 3d 36 33 33 37
0150: 31 39 34 61 32 32 33 32 36 62 35 39 36 61 35 32
0160: 33 36 31 61 30 32 34 32 32 30 34 31 0a 41 45 53
0170: 5f 4d 4f 44 45 3d 43 42 43 0a

Decoded as ASCII:
AES_KEY=b5e00e7a785cffbfed0d4023e3bc3b5ede514eb8665482e9a61221ea9184ded0
IV=6337194a22326b596a52361a02422041
AES_MODE=CBC

We now have everything needed to decrypt the flag.
7. Decrypt the flag
Recovered values:
Ciphertext:
1730224ef5f5848908754f2cbea80f9782e30aea053f41b599a937e2778a4d8d

AES key:
b5e00e7a785cffbfed0d4023e3bc3b5ede514eb8665482e9a61221ea9184ded0

IV:
6337194a22326b596a52361a02422041

Mode:
AES-256-CBC

Decrypt with OpenSSL:
echo 1730224ef5f5848908754f2cbea80f9782e30aea053f41b599a937e2778a4d8d \
| xxd -r -p \
| openssl enc -d -aes-256-cbc \
-K b5e00e7a785cffbfed0d4023e3bc3b5ede514eb8665482e9a61221ea9184ded0 \
-iv 6337194a22326b596a52361a02422041

This reveals the final flag.
Summary
The intended path was:
U-Boot shell
    ↓
EEPROM loading errors
    ↓
enumerate I2C buses
    ↓
find EEPROM at 0x50
    ↓
bus 1 @ offset 0x800
    ↓
recover old U-Boot environment
    ↓
recover encrypted_flag
    ↓
bus 0 @ offset 0x100
    ↓
recover AES key + IV + CBC mode
    ↓
AES-256-CBC decrypt
    ↓
flag

The key lesson is that even when U-Boot rejects an environment because of an invalid CRC, the raw data may still be fully recoverable by reading the EEPROM directly."