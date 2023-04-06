`default_nettype none

`timescale 1 ns / 1 ps

`define CLK_DIV 3'b010

module clock_div #(
    parameter SIZE = 3		// Number of bits for the divider value
) (
    in, out, N, resetb
);
    input in;			// input clock
    input [SIZE-1:0] N;		// the number to be divided by
    input resetb;		// asynchronous reset (sense negative)
    output out;			// divided output clock
 
    wire out_odd;		// output of odd divider
    wire out_even;		// output of even divider
    wire not_zero;		// signal to find divide by 0 case
    wire enable_even;		// enable of even divider
    wire enable_odd;		// enable of odd divider

    reg [SIZE-1:0] syncN;	// N synchronized to output clock
    reg [SIZE-1:0] syncNp;	// N synchronized to output clock
 
    assign not_zero = | syncN[SIZE-1:1];
 
    assign out = (out_odd & syncN[0] & not_zero) | (out_even & !syncN[0]);
    assign enable_odd = syncN[0] & not_zero;
    assign enable_even = !syncN[0];

    // Divider value synchronization (double-synchronized to avoid metastability)
    always @(posedge out or negedge resetb) begin
	if (resetb == 1'b0) begin
	    syncN <= `CLK_DIV;	// Default to divide-by-2 on system reset
	    syncNp <= `CLK_DIV;	// Default to divide-by-2 on system reset
	end else begin
	    syncNp <= N;
	    syncN <= syncNp;
	end
    end
 
    // Even divider
    even even_0(in, out_even, syncN, resetb, not_zero, enable_even);
    // Odd divider
    odd odd_0(in, out_odd, syncN, resetb, enable_odd);
 
endmodule // clock_div
 
/* Odd divider */

module odd #(
    parameter SIZE = 3
) (
    clk, out, N, resetb, enable
);
    input clk;			// slow clock
    output out;			// fast output clock
    input [SIZE-1:0] N;		// division factor
    input resetb;		// synchronous reset
    input enable;		// odd enable
 
    reg [SIZE-1:0] counter;	// these 2 counters are used
    reg [SIZE-1:0] counter2;	// to non-overlapping signals
    reg out_counter;		// positive edge triggered counter
    reg out_counter2;		// negative edge triggered counter
    reg rst_pulse;		// pulse generated when vector N changes
    reg [SIZE-1:0] old_N;	// gets set to old N when N is changed
    wire not_zero;		// if !not_zero, we devide by 1
 
    // xor to generate 50% duty, half-period waves of final output
    assign out = out_counter2 ^ out_counter;

    // positive edge counter/divider
    always @(posedge clk or negedge resetb) begin
	if (resetb == 1'b0) begin
	    counter <= `CLK_DIV;
	    out_counter <= 1;
	end else if (rst_pulse) begin
	    counter <= N;
	    out_counter <= 1;
	end else if (enable) begin
	    if (counter == 1) begin
		counter <= N;
		out_counter <= ~out_counter;
	    end else begin
		counter <= counter - 1'b1;
	    end
	end
    end
 
    reg [SIZE-1:0] initial_begin;	// this is used to offset the negative edge counter
    wire [SIZE:0] interm_3;		// from the positive edge counter in order to
    assign interm_3 = {1'b0, N} + 2'b11;	// guarantee 50% duty cycle.

    localparam [SIZE:0] interm_init = {1'b0,`CLK_DIV} + 2'b11;

    // Counter driven by negative edge of clock.

    always @(negedge clk or negedge resetb) begin
	if (resetb == 1'b0) begin
	    // reset the counter at system reset
	    counter2 <= `CLK_DIV;
	    initial_begin <= interm_init[SIZE:1];
	    out_counter2 <= 1;
	end else if (rst_pulse) begin
	    // reset the counter at change of N.
	    counter2 <= N;
	    initial_begin <= interm_3[SIZE:1];
	    out_counter2 <= 1;
	end else if ((initial_begin <= 1) && enable) begin

	    // Do normal logic after odd calibration.
	    // This is the same as the even counter.
	    if (counter2 == 1) begin
		counter2 <= N;
		out_counter2 <= ~out_counter2;
	    end else begin
		counter2 <= counter2 - 1'b1;
	    end
	end else if (enable) begin
	    initial_begin <= initial_begin - 1'b1;
	end
    end
 
    //
    // reset pulse generator:
    //               __    __    __    __    _
    // clk:       __/  \__/  \__/  \__/  \__/
    //            _ __________________________
    // N:         _X__________________________
    //               _____
    // rst_pulse: __/     \___________________
    //
    // This block generates an internal reset for the odd divider in the
    // form of a single pulse signal when the odd divider is enabled.

    always @(posedge clk or negedge resetb) begin
	if (resetb == 1'b0) begin
	    rst_pulse <= 0;
	end else if (enable) begin
	    if (N != old_N) begin
		// pulse when reset changes
		rst_pulse <= 1;
	    end else begin
		rst_pulse <= 0;
	    end
	end
    end
 
    always @(posedge clk) begin
	// always save the old N value to guarante reset from
	// an even-to-odd transition.
	old_N <= N;
    end	
 
endmodule // odd

/* Even divider */

module even #(
    parameter SIZE = 3
) (
    clk, out, N, resetb, not_zero, enable
);
    input clk;		// fast input clock
    output out;		// slower divided clock
    input [SIZE-1:0] N;	// divide by factor 'N'
    input resetb;	// asynchronous reset
    input not_zero;	// if !not_zero divide by 1
    input enable;	// enable the even divider
 
    reg [SIZE-1:0] counter;
    reg out_counter;
    wire [SIZE-1:0] div_2;
 
    // if N=0 just output the clock, otherwise, divide it.
    assign out = (clk & !not_zero) | (out_counter & not_zero);
    assign div_2 = {1'b0, N[SIZE-1:1]};
 
    // simple flip-flop even divider
    always @(posedge clk or negedge resetb) begin
	if (resetb == 1'b0) begin
	    counter <= 1;
	    out_counter <= 1;

	end else if (enable) begin
	    // only use switching power if enabled
	    if (counter == 1) begin
		// divide after counter has reached bottom
		// of interval 'N' which will be value '1'
		counter <= div_2;
		out_counter <= ~out_counter;
	    end else begin
		// decrement the counter and wait
		counter <= counter-1;	// to start next transition.
	    end
	end
    end
 
endmodule //even

module caravel_clocking(
`ifdef USE_POWER_PINS
    input VPWR,
    input VGND,
`endif
    input resetb, 	// Master (negative sense) reset
    input ext_clk_sel,	// 0=use PLL clock, 1=use external (pad) clock
    input ext_clk,	// External pad (slow) clock
    input pll_clk,	// Internal PLL (fast) clock
    input pll_clk90,	// Internal PLL (fast) clock, 90 degree phase
    input [2:0] sel,	// Select clock divider value (0=thru, 1=divide-by-2, etc.)
    input [2:0] sel2,	// Select clock divider value for 90 degree phase divided clock
    input ext_reset,	// Positive sense reset from housekeeping SPI.
    output core_clk,	// Output core clock
    output user_clk,	// Output user (secondary) clock
    output resetb_sync	// Output propagated and buffered reset
);

    wire pll_clk_sel;
    wire pll_clk_divided;
    wire pll_clk90_divided;
    wire core_ext_clk;
    reg  use_pll_first;
    reg  use_pll_second;
    reg	 ext_clk_syncd_pre;
    reg	 ext_clk_syncd;

    assign pll_clk_sel = ~ext_clk_sel;

    // Note that this implementation does not guard against switching to
    // the PLL clock if the PLL clock is not present.

    always @(posedge pll_clk or negedge resetb) begin
	if (resetb == 1'b0) begin
	    use_pll_first <= 1'b0;
	    use_pll_second <= 1'b0;
	    ext_clk_syncd <= 1'b0;
	end else begin
	    use_pll_first <= pll_clk_sel;
	    use_pll_second <= use_pll_first;
	    ext_clk_syncd_pre <= ext_clk;	// Sync ext_clk to pll_clk
	    ext_clk_syncd <= ext_clk_syncd_pre;	// Do this twice (resolve metastability)
	end
    end

    // Apply PLL clock divider

    clock_div #(
	.SIZE(3)
    ) divider (
	.in(pll_clk),
	.out(pll_clk_divided),
	.N(sel),
	.resetb(resetb)
    ); 

    // Secondary PLL clock divider for user space access

    clock_div #(
	.SIZE(3)
    ) divider2 (
	.in(pll_clk90),
	.out(pll_clk90_divided),
	.N(sel2),
	.resetb(resetb)
    ); 


    // Multiplex the clock output

    assign core_ext_clk = (use_pll_first) ? ext_clk_syncd : ext_clk;
    assign core_clk = (use_pll_second) ? pll_clk_divided : core_ext_clk;
    assign user_clk = (use_pll_second) ? pll_clk90_divided : core_ext_clk;

    // Reset assignment.  "reset" comes from POR, while "ext_reset"
    // comes from standalone SPI (and is normally zero unless
    // activated from the SPI).

    // Staged-delay reset
    reg [2:0] reset_delay;

    always @(negedge core_clk or negedge resetb) begin
        if (resetb == 1'b0) begin
        reset_delay <= 3'b111;
        end else begin
        reset_delay <= {1'b0, reset_delay[2:1]};
        end
    end

    assign resetb_sync = ~(reset_delay[0] | ext_reset);

endmodule

module clock_tb;
	reg clock;

	always #12.5 clock <= (clock === 1'b0);

	initial begin
		clock = 0;
	end

	initial begin
		$dumpfile("clock_tb.vcd");
		$dumpvars(0, clock_tb);

		// Repeat cycles of 1000 clock edges as needed to complete testbench
		repeat (1) begin
			repeat (100) @(posedge clock);
			// $display("+1000 cycles");
		end
		$display("%c[1;31m",27);
		`ifdef GL
			$display ("Monitor: Timeout(GL)");
		`else
			$display ("Monitor: Timeout,(RTL)");
		`endif
		$display("%c[0m",27);
		$finish;
	end

	wire ext_clk_sel = 0;
	wire clock_core_buf;
	wire pll_clk;
	wire pll_clk90;
	reg rstb_l_buf = 0;
	reg [2:0] spi_pll_sel = 2;
	reg [2:0] spi_pll90_sel = 3;

	assign clock_core_buf = clock;
	assign pll_clk = clock;
	assign pll_clk90 = clock;

	initial begin
		#5
		rstb_l_buf = 1;
	end

	caravel_clocking clock_ctrl (
    `ifdef USE_POWER_PINS
		.VPWR(vccd_core),
		.VGND(vssd_core),
    `endif
        .ext_clk_sel(ext_clk_sel),
        .ext_clk(clock_core_buf),
        .pll_clk(pll_clk),
        .pll_clk90(pll_clk90),
        .resetb(rstb_l_buf),
        .sel(spi_pll_sel),
        .sel2(spi_pll90_sel),
        .ext_reset(),  // From housekeeping SPI
        .core_clk(),
        .user_clk(),
        .resetb_sync()
    );

endmodule
`default_nettype wire
