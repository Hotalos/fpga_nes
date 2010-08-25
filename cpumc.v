///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: cpumc
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 08/21/2010
//
// Description:
// 
// CPU Memory Controller.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module cpumc
(
  input  wire        clk,         // 50MHz system clock signal
  input  wire        wr,          // write enable signal
  input  wire [15:0] addr,        // 16-bit memory address
  inout  wire [ 7:0] data,        // data bits (input/output)
  output reg         invalid_req  // invalid request signal (1 on error, 0 on success)
);

reg  [ 7:0] out_data;

wire [10:0] ram_addr;
wire [ 7:0] ram_rd_data;
reg         ram_wr;

wire [13:0] prgrom_lo_addr;
wire [ 7:0] prgrom_lo_rd_data;
reg         prgrom_lo_wr;

wire [13:0] prgrom_hi_addr;
wire [ 7:0] prgrom_hi_rd_data;
reg         prgrom_hi_wr;

// CPU Memory Map
//   0x0000 - 0x1FFF RAM           (0x0800 - 0x1FFF mirrors 0x0000 - 0x07FF)
//   0x2000 - 0x401F I/O Regs      (0x2008 - 0x3FFF mirrors 0x2000 - 0x2007)
//   0x4020 - 0x5FFF Expansion ROM (currently unsupported)
//   0x6000 - 0x7FFF SRAM          (currently unsupported)
//   0x8000 - 0xBFFF PRG-ROM LO
//   0xC000 - 0xFFFF PRG-ROM HI

// Block ram instance for "RAM" memory range (0x0000 - 0x1FFF).  0x0800 - 0x1FFF mirrors 0x0000 -
// 0x07FF, so we only need 2048 bytes of physical block ram.
dual_port_ram_sync #(.ADDR_WIDTH(11),
                     .DATA_WIDTH(8)) ram(
  .clk(clk),
  .we(ram_wr),
  .addr_a(ram_addr),
  .din_a(data),
  .dout_a(ram_rd_data),
  .addr_b(11'h000)
);

assign ram_addr = addr[10:0];

// Block ram instance for "PRG-ROM LO" memory range (0x8000 - 0xBFFF).
dual_port_ram_sync #(.ADDR_WIDTH(14),
                     .DATA_WIDTH(8)) prgrom_lo(
  .clk(clk),
  .we(prgrom_lo_wr),
  .addr_a(prgrom_lo_addr),
  .din_a(data),
  .dout_a(prgrom_lo_rd_data),
  .addr_b(14'h0000)
);

assign prgrom_lo_addr = addr[13:0];

// Block ram instance for "PRG-ROM HI" memory range (0xC000 - 0xFFFF).
dual_port_ram_sync #(.ADDR_WIDTH(14),
                     .DATA_WIDTH(8)) prgrom_hi(
  .clk(clk),
  .we(prgrom_hi_wr),
  .addr_a(prgrom_hi_addr),
  .din_a(data),
  .dout_a(prgrom_hi_rd_data),
  .addr_b(14'h0000)
);

assign prgrom_hi_addr = addr[13:0];

always @*
  begin
    ram_wr       = 1'b0;
    prgrom_lo_wr = 1'b0;
    prgrom_hi_wr = 1'b0;

    invalid_req  = 1'b0;

    if (addr[15:13] == 0)
      begin
        // RAM range (0x0000 - 0x1FFF).
        out_data = ram_rd_data;
        ram_wr   = wr;
      end
    else if (addr[15:14] == 2'b10)
      begin
        // PRG-ROM LO range (0x8000 - 0xBFFF).
        out_data     = prgrom_lo_rd_data;
        prgrom_lo_wr = prgrom_lo_wr;
      end
    else if (addr[15:14] == 2'b11)
      begin
        // PRG-ROM HI range (0xC000 - 0xFFFF).
        out_data     = prgrom_hi_rd_data;
        prgrom_hi_wr = prgrom_hi_wr;
      end
    else
      begin
        out_data    = 8'hcd;
        invalid_req = 1'b1;
      end
  end

assign data = (wr) ? 8'bzzzzzzzz : out_data;

endmodule

