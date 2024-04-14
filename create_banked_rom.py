#!/usr/bin/python3
import sys

boot_rom_file   = "bootloader.cim"
cpm_system_file = "cpm22.bin"
output_rom_file = "sega-cpm.sc"

cpm_system_fh = open(cpm_system_file, "rb")
cpm_system = (b'\xE5' * 128); # Skip first (cold start) sector.
cpm_system += cpm_system_fh.read()
cpm_system_fh.close()

output_fh = open(output_rom_file, "wb")

# Bank #00: RAM
output_fh.write(b'\x00' * 32768)

# Banks #01 -> #10: Disk image A
# Banks #11 -> #20: Disk image B
# Banks #21 -> #30: Disk image C
# Banks #31 -> #40: Disk image D
for disk_no in range(1, 5):
	try:
		disk_fh = open(sys.argv[disk_no], "rb")
		print("Disk %s: '%s'" % (chr(disk_no + 0x40), sys.argv[disk_no]))
		for i in range(0, 10):
			# 8 tracks * 26 sectors * 128 sector size for each bank.
			data = disk_fh.read(8 * 26 * 128);
			if i == 0:
				# Replace first tracks with CP/M for later reloading.
				data = cpm_system + data[len(cpm_system):]
			output_fh.write(data)
			# Pad the rest with the uninitialized byte:
			output_fh.write(b'\xE5' * (32768 - len(data)))
		disk_fh.close()
	except IOError:
		print("Warning: Unable to open: %s" % sys.argv[disk_no])
		# Fill with the uninitialized byte
		output_fh.write(b'\xE5' * (32768 * 10))
	except IndexError:
		print("Disk %s: Not Used" % (chr(disk_no + 0x40)))
		# Fill with the uninitialized byte
		output_fh.write(b'\xE5' * (32768 * 10))

# Banks #41->#62: Unused
output_fh.write(b'\x00' * (32768 * 22))

# Bank #63: CP/M bootloader ROM
cpm_rom_fh = open(boot_rom_file, "rb")
data = cpm_rom_fh.read();
output_fh.write(data)
output_fh.write(b'\x00' * (32768 - len(data)))
cpm_rom_fh.close()

output_fh.close()

