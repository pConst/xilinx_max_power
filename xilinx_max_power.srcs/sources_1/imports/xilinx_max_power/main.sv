// Konstantin Pavlov, pavlovconst@gmail.com

// 'Xilinx_max_power' project
//
// designed for Digilent Arty-Z7020 board
// based on ZINQ-7000 series SOC, part number xc7z020clg400-1
// but can be used for any modern Xilinx FPGA or SOC chip

`timescale 1ns / 1ps

module main(

    input clk,
    input [4:0] btn
);

logic rst;
assign rst = btn[0];  // external reset

logic pll1_locked;
clk_wiz_0 PLL1 (
  .clk_in1( clk ),
  .reset( 1'b0 ),
  .locked( pll1_locked ),
  .clk_out1( clk500 )  // generating high-frequency clock to increase FPGA
                      // dinamic power consumption
);

logic sig100tr = 0;
always_ff @(posedge clk500) begin
  if (rst) begin
    sig100tr <= 0;
  end else begin
    sig100tr <= ~sig100tr;  // a signal with 100% toggle rate at 500MHz
  end
end


// 1. Loading power by SRLs (shift registers based on LUTs)
// The simplest way to load Xilinx FPGA is to infer SRL16 or SRL32  primitives

//`define INFER_SRLS  // defined by default
`ifdef INFER_SRLS

    localparam N1 = 6000;  // number of SRLs to infer

    (* DONT_TOUCH = "TRUE" *)  SRLC32E #(
      .INIT(32'h00000000) // Initial Value of Shift Register
    ) SRLC32E_1 [N1:1] (
      .Q(  ),     // SRL data output
      .Q31(  ), // SRL cascade output pin
      .A( 5'b11111 ),     // 5-bit shift depth select input
      .CE( 1'b1 ),   // Clock enable input
      .CLK( clk500 ), // Clock input
      .D( sig100tr )      // SRL data input
    );
`endif

// 2. Loading power by integrated block RAM blocks

//`define INFER_BRAMS
`ifdef INFER_BRAMS

    localparam N2 = 35;

    (* DONT_TOUCH = "TRUE" *)  FIFO36E1 #(
      .ALMOST_EMPTY_OFFSET(13'h0080),    // Sets the almost empty threshold
      .ALMOST_FULL_OFFSET(13'h0080),     // Sets almost full threshold
      .DATA_WIDTH(72),                   // Sets data width to 4-72
      .DO_REG(1),                        // Enable output register (1-0) Must be 1 if EN_SYN = FALSE
      .EN_ECC_READ("TRUE"),              // Enable ECC decoder, FALSE, TRUE
      .EN_ECC_WRITE("TRUE"),             // Enable ECC encoder, FALSE, TRUE
      .EN_SYN("FALSE"),                  // Specifies FIFO as Asynchronous (FALSE) or Synchronous (TRUE)
      .FIFO_MODE("FIFO36_72"),           // Sets mode to "FIFO36" or "FIFO36_72"
      .FIRST_WORD_FALL_THROUGH("FALSE"), // Sets the FIFO FWFT to FALSE, TRUE
      .INIT(72'h000000000000000000),     // Initial values on output port
      .SIM_DEVICE("7SERIES"),            // Must be set to "7SERIES" for simulation behavior
      .SRVAL(72'h000000000000000000)     // Set/Reset value for output port
    )
    FIFO36E1_1 [N2:1]  (
      // ECC Signals: 1-bit (each) output: Error Correction Circuitry ports
      .DBITERR(  ),             // 1-bit output: Double bit error status
      .ECCPARITY(  ),         // 8-bit output: Generated error correction parity
      .SBITERR(  ),             // 1-bit output: Single bit error status
      // Read Data: 64-bit (each) output: Read output data
      .DO(  ),                       // 64-bit output: Data output
      .DOP(  ),                     // 8-bit output: Parity data output
      // Status: 1-bit (each) output: Flags and other FIFO status outputs
      .ALMOSTEMPTY(  ),     // 1-bit output: Almost empty flag
      .ALMOSTFULL(  ),       // 1-bit output: Almost full flag
      .EMPTY(  ),                 // 1-bit output: Empty flag
      .FULL(  ),                   // 1-bit output: Full flag
      .RDCOUNT(  ),             // 13-bit output: Read count
      .RDERR(  ),                 // 1-bit output: Read error
      .WRCOUNT(  ),             // 13-bit output: Write count
      .WRERR(  ),                 // 1-bit output: Write error
      // ECC Signals: 1-bit (each) input: Error Correction Circuitry ports
      .INJECTDBITERR( 1'b0 ), // 1-bit input: Inject a double bit error input
      .INJECTSBITERR( 1'b0 ),
      // Read Control Signals: 1-bit (each) input: Read clock, enable and reset input signals
      .RDCLK( ~clk500 ),                 // 1-bit input: Read clock
      .RDEN( 1'b1 ),                   // 1-bit input: Read enable
      .REGCE( 1'b1 ),                 // 1-bit input: Clock enable
      .RST( ~pll1_locked ),                     // 1-bit input: Reset
      .RSTREG( 1'b1 ),               // 1-bit input: Output register set/reset
      // Write Control Signals: 1-bit (each) input: Write clock and enable input signals
      .WRCLK( clk500 ),                 // 1-bit input: Rising edge write clock.
      .WREN( 1'b1 ),                   // 1-bit input: Write enable
      // Write Data: 64-bit (each) input: Write input data
      .DI( {64{sig100tr}} ),                       // 64-bit input: Data input
      .DIP( {8{sig100tr}} )                      // 8-bit input: Parity input
    );
`endif

// 3. Loading power by registers
// Dont use this feature untill you cant drain enough power by previous options
// because this step takes A LOT of time to synthesize and implement

//`define INFER_REGS
`ifdef INFER_REGS

    localparam N3 = 50000;  // number of registers to infer

    (* DONT_TOUCH = "TRUE" *)  FDCE #(
      .INIT( 1'b0 ) // Initial value of register (1'b0 or 1'b1)
    ) FDCE_1 [N3:1] (
      .Q(  ),      // 1-bit Data output
      .C( clk500 ),      // 1-bit Clock input
      .CE( 1'b1 ),    // 1-bit Clock enable input
      .CLR( 1'b0 ),  // 1-bit Asynchronous clear input
      .D( sig100tr )       // 1-bit Data input
    );
`endif

endmodule
