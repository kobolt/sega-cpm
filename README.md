# CP/M for Sega SG-1000/SC-3000
This project is a proof-of-concept that builds a special bank-switched CP/M cartridge that can be loaded with an emulator.

## Implementation Notes
* Four IBM 3740 compatible floppy disk images can be stored in the ROM banks.
* One 32K bank holds 8 tracks with 26 sectors that are 128 bytes each.
* Bank switching uses the "SC-3000 Survivors Multicart" style.
* The first bank is a writable RAM area, this is critical for CP/M to function.
* The last bank is a bootloader that loads CP/M into the upper RAM area.
* The bootloader also initializes the TMS9918 video chip and loads font data.
* Font data is borrowed from the Sega BASIC cartridge.
* The cursor is not visible!
* Only standard ASCII control characters CR, LF and BS are supported.
* Screen is only 40 columns wide, but output wraps and the screen scrolls.
* SK-1100 keyboard is polled on the IRQ generated by the TMS9918 chip.
* Floppy disk access is read-only, writing will result in a "BDOS error".
* Works with [SG-Touzen](https://github.com/kobolt/sgtouzen) or a modified [MAME](https://www.mamedev.org/) or a modified [MEKA](https://www.smspower.org/meka/) emulator.
* MAME and MEKA must be modified since no mapper exists for this cartridge.

## Additional Information Links
* [Blog: CP/M for Sega SG-1000/SC-3000](https://kobolt.github.io/article-233.html)
* [YouTube: CP/M on Sega SC-3000](https://www.youtube.com/watch?v=vhEXx4vPP1A)

## Build
The [zmac](http://48k.ca/zmac.html) Z80 assembler is required.
Python 3 is used to merge everything into a banked ROM file.
Put floppy disk images "disk-a.img", "disk-b.img", "disk-c.img" and "disk-d.img" in the source code directory.
If a floppy disk image is missing then dummy data with 0xE5 will be written instead.
Just run make:
```
make
```
Load the resulting "sega-cpm.sc" ROM cartridge file into the emulator.

## MAME Modification
Based on MAME version 0.260 source code.
This modification causes the multicart mapper to allow writing to the cartridge area:
```
--- src/devices/bus/sega8/rom.cpp.orig  2000-01-01 00:00:00.000000000 +0000
+++ src/devices/bus/sega8/rom.cpp       2000-01-01 00:00:00.000000000 +0000
@@ -1132,6 +1132,8 @@
        // 16K of RAM sits in 0x8000-0xbfff
        if (offset >= 0x8000)
                m_ram[offset & 0x3fff] = data;
+        else
+                m_rom[(offset & 0x7fff) | (m_block << 15) % m_rom_size] = data;
 }

 uint8_t sega8_multicart_device::read_ram(offs_t offset)
```

## MEKA Modification
Based on MEKA version 0.80-alpha source code.
The first modification removes the multicart signature check:
```
--- meka/srcs/machine.cpp.orig  2000-01-01 00:00:00.000000000 +0000
+++ meka/srcs/machine.cpp       2000-01-01 00:00:00.000000000 +0000
@@ -219,7 +219,7 @@
         else
             g_machine.mapper = MAPPER_SG1000;
         if (DB.current_entry == NULL && tsms.Size_ROM >= 0x200000)
-            if (memcmp(ROM+0x1F8004, "SC-3000 SURVIVORS MULTICART BOOT MENU", 38) == 0)
+//            if (memcmp(ROM+0x1F8004, "SC-3000 SURVIVORS MULTICART BOOT MENU", 38) == 0)
                 g_machine.mapper = MAPPER_SC3000_Survivors_Multicart;
         return;
     case DRV_COLECO:
```
The second modification makes the cartridge area writable:
```
--- meka/srcs/mappers.cpp.orig  2000-01-01 00:00:00.000000000 +0000
+++ meka/srcs/mappers.cpp       2000-01-01 00:00:00.000000000 +0000
@@ -286,7 +286,7 @@
 WRITE_FUNC (Write_Mapper_32kRAM)
 {
     const unsigned int page = (Addr >> 13);
-    if (page >= 4)
+//    if (page >= 4)
     {
         Mem_Pages[page][Addr] = Value; return;
     }
```

## Cartridge Bank Layout
| Bank | Contents                |
| ---- | ----------------------- |
| 00   | RAM                     |
| 01   | Disk A: Tracks  0 to 7  |
| 02   | Disk A: Tracks  8 to 15 |
| 03   | Disk A: Tracks 16 to 23 |
| 04   | Disk A: Tracks 24 to 31 |
| 05   | Disk A: Tracks 32 to 39 |
| 06   | Disk A: Tracks 40 to 47 |
| 07   | Disk A: Tracks 48 to 55 |
| 08   | Disk A: Tracks 56 to 63 |
| 09   | Disk A: Tracks 64 to 71 |
| 10   | Disk A: Tracks 72 to 79 |
| 11   | Disk B: Tracks  0 to 7  |
| 12   | Disk B: Tracks  8 to 15 |
| 13   | Disk B: Tracks 16 to 23 |
| 14   | Disk B: Tracks 24 to 31 |
| 15   | Disk B: Tracks 32 to 39 |
| 16   | Disk B: Tracks 40 to 47 |
| 17   | Disk B: Tracks 48 to 55 |
| 18   | Disk B: Tracks 56 to 63 |
| 19   | Disk B: Tracks 64 to 71 |
| 20   | Disk B: Tracks 72 to 79 |
| 21   | Disk C: Tracks  0 to 7  |
| 22   | Disk C: Tracks  8 to 15 |
| 23   | Disk C: Tracks 16 to 23 |
| 24   | Disk C: Tracks 24 to 31 |
| 25   | Disk C: Tracks 32 to 39 |
| 26   | Disk C: Tracks 40 to 47 |
| 27   | Disk C: Tracks 48 to 55 |
| 28   | Disk C: Tracks 56 to 63 |
| 29   | Disk C: Tracks 64 to 71 |
| 30   | Disk C: Tracks 72 to 79 |
| 31   | Disk D: Tracks  0 to 7  |
| 32   | Disk D: Tracks  8 to 15 |
| 33   | Disk D: Tracks 16 to 23 |
| 34   | Disk D: Tracks 24 to 31 |
| 35   | Disk D: Tracks 32 to 39 |
| 36   | Disk D: Tracks 40 to 47 |
| 37   | Disk D: Tracks 48 to 55 |
| 38   | Disk D: Tracks 56 to 63 |
| 39   | Disk D: Tracks 64 to 71 |
| 40   | Disk D: Tracks 72 to 79 |
| 41   | Unused                  |
| 42   | Unused                  |
| 43   | Unused                  |
| 44   | Unused                  |
| 45   | Unused                  |
| 46   | Unused                  |
| 47   | Unused                  |
| 48   | Unused                  |
| 49   | Unused                  |
| 50   | Unused                  |
| 51   | Unused                  |
| 52   | Unused                  |
| 53   | Unused                  |
| 54   | Unused                  |
| 55   | Unused                  |
| 56   | Unused                  |
| 57   | Unused                  |
| 58   | Unused                  |
| 59   | Unused                  |
| 60   | Unused                  |
| 61   | Unused                  |
| 62   | Unused                  |
| 63   | Bootloader              |

