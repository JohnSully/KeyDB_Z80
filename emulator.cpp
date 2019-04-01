#include <z80ex/z80ex.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

#define MEM_SIZE (32*1024)	// 32KB of glorious SRAM
Z80EX_BYTE memory[MEM_SIZE];

void avcheck(Z80EX_WORD addr, int fWrite)
{
	if (addr >= MEM_SIZE)
	{
		printf("Access violation %s address %Xh\n",
				fWrite ? "writing" : "reading",
				addr);
		exit(EXIT_FAILURE);
	}
}

/*read byte from memory <addr> -- called when RD & MREQ goes active.
m1_state will be 1 if M1 signal is active*/
Z80EX_BYTE mread_cb(Z80EX_CONTEXT *cpu, Z80EX_WORD addr, int m1_state, void *user_data)
{
	avcheck(addr, 0);
	return memory[addr];
}

/*write <value> to memory <addr> -- called when WR & MREQ goes active*/
void mwrite_cb(Z80EX_CONTEXT *cpu, Z80EX_WORD addr, Z80EX_BYTE value, void *user_data)
{
	avcheck(addr, 1);
	memory[addr] = value;
}

/*read byte from <port> -- called when RD & IORQ goes active*/
Z80EX_BYTE pread_cb(Z80EX_CONTEXT *cpu, Z80EX_WORD port, void *user_data)
{
	if ((port & 0xFF)  == 0x25)
		return 0x21;

	char buf;
	ssize_t cb = read(STDIN_FILENO, &buf, 1);
	if (cb != 1)
	{
		perror("Failed to read byte");
		exit(EXIT_FAILURE);
	}
	return buf;
}

/*write <value> to <port> -- called when WR & IORQ goes active*/
void pwrite_cb(Z80EX_CONTEXT *cpu, Z80EX_WORD port, Z80EX_BYTE value, void *user_data)
{
	ssize_t cb = write(STDOUT_FILENO, &value, 1);
	if (cb != 1)
	{
		perror("Failed to write byte");
		exit(EXIT_FAILURE);
	}
}


int main()
{
	FILE *f = fopen("keydb.bin", "rb");
	if (f == NULL)
	{
		perror("Failed to open file");
		return EXIT_FAILURE;
	}

	ssize_t base = 0x40;
	ssize_t cb;
	ssize_t offset = base;
	while ((cb = fread(memory + offset, 1, (MEM_SIZE-offset), f)))
	{
		offset += cb;
		if (cb == 0)
			break;
		if (offset >= MEM_SIZE)
			break;
	}
	if (offset == base)
	{
		perror("Failed to read code file");
		return EXIT_FAILURE;
	}

	Z80EX_CONTEXT *cpu;
	cpu = z80ex_create(mread_cb, nullptr, 
			mwrite_cb, nullptr,
			pread_cb, nullptr,
			pwrite_cb, nullptr,
			nullptr, nullptr
			);
	z80ex_set_reg(cpu, regPC, base);

	for (;;)
	{
		z80ex_step(cpu);
		if (z80ex_doing_halt(cpu))
			break;	// program done
	}

	fclose(f);
	return EXIT_SUCCESS;
}
