(* use_dsp = "no" *)

`define WIDTH 640
`define HEIGHT 480

module VGA (

    input  clk,       // 25 MHz
    input  reset,     // Active high
    input  [11:0]   color_in, 
    output [ 9:0]   next_x,   // x-coordinate of NEXT pixel that will be drawn
    output [ 9:0]   next_y,   // y-coordinate of NEXT pixel that will be drawn
    
    output wire hsync,        // HSYNC (to VGA connector)
    output wire vsync,        // VSYNC (to VGA connctor)
    
    output [3:0] vga_red,     // RED (to resistor DAC VGA connector)
    output [3:0] vga_green,   // GREEN (to resistor DAC to VGA connector)
    output [3:0] vga_blue,    // BLUE (to resistor DAC to VGA connector)
    
    output sync,              // SYNC to VGA connector
    output blank              // BLANK to VGA connector
);
    // Horizontal parameters (measured in clock cycles)
    parameter [9:0] H_ACTIVE  =  10'd639 ;
    parameter [9:0] H_FRONT   =  10'd15 ;
    parameter [9:0] H_PULSE   =  10'd95 ;
    parameter [9:0] H_BACK    =  10'd47 ;

    // Vertical parameters (measured in lines)
    parameter [9:0] V_ACTIVE   =  10'd479 ;
    parameter [9:0] V_FRONT    =  10'd9   ;
    parameter [9:0] V_PULSE    =  10'd1   ;
    parameter [9:0] V_BACK     =  10'd32  ;

    // Parameters for readability
    parameter   LOW     = 1'b0 ;
    parameter   HIGH    = 1'b1 ;

    // States (more readable)
    parameter   [7:0]   H_ACTIVE_STATE  = 8'd0 ;
    parameter   [7:0]   H_FRONT_STATE   = 8'd1 ;
    parameter   [7:0]   H_PULSE_STATE   = 8'd2 ;
    parameter   [7:0]   H_BACK_STATE    = 8'd3 ;

    parameter   [7:0]   V_ACTIVE_STATE  = 8'd0 ;
    parameter   [7:0]   V_FRONT_STATE   = 8'd1 ;
    parameter   [7:0]   V_PULSE_STATE   = 8'd2 ;
    parameter   [7:0]   V_BACK_STATE    = 8'd3 ;

    // Clocked registers
    reg             hsync_reg;
    reg             vsync_reg;
    reg     [3:0]   red_reg;
    reg     [3:0]   green_reg;
    reg     [3:0]   blue_reg;
    reg             line_done;

    // Control registers
    reg     [9:0]   h_counter;
    reg     [9:0]   v_counter;

    reg     [7:0]    h_state;
    reg     [7:0]    v_state;
    
    initial
    begin
        hsync_reg <= 0;
        vsync_reg <= 0;
        red_reg <= 0;
        green_reg <= 0;
        blue_reg <= 0;
        line_done <= LOW;
        h_counter <= 0;
        v_counter <= 0;
        h_state <= H_ACTIVE_STATE;
        v_state <= V_ACTIVE_STATE;
    end

    // State machine
    always@(posedge clk or posedge reset) begin
        // At reset . . .
        if (reset) begin
            hsync_reg <= 0;
            vsync_reg <= 0;
            red_reg <= color_in[11:8];
            green_reg <= color_in[7:4];
            blue_reg <= color_in[3:0];
            line_done <= LOW;
            h_counter <= 0;
            v_counter <= 0;
            h_state <= H_ACTIVE_STATE;
            v_state <= V_ACTIVE_STATE;
        end
        else begin
            //////////////////////////////////////////////////////////////////////////
            ///////////////////////// HORIZONTAL /////////////////////////////////////
            //////////////////////////////////////////////////////////////////////////
            if (h_state == H_ACTIVE_STATE) begin
                // Iterate horizontal counter, zero at end of ACTIVE mode
                h_counter <= (h_counter==H_ACTIVE)?10'd0:(h_counter + 10'd1) ;
                // Set hsync
                hsync_reg <= HIGH ;
                // Deassert line done
                line_done <= LOW ;
                // State transition
                h_state <= (h_counter == H_ACTIVE)?H_FRONT_STATE:H_ACTIVE_STATE ;
            end
            if (h_state == H_FRONT_STATE) begin
                // Iterate horizontal counter, zero at end of H_FRONT mode
                h_counter <= (h_counter==H_FRONT)?10'd0:(h_counter + 10'd1) ;
                // Set hsync
                hsync_reg <= HIGH ;
                // State transition
                h_state <= (h_counter == H_FRONT)?H_PULSE_STATE:H_FRONT_STATE ;
            end
            if (h_state == H_PULSE_STATE) begin
                // Iterate horizontal counter, zero at end of H_PULSE mode
                h_counter <= (h_counter==H_PULSE)?10'd0:(h_counter + 10'd1) ;
                // Clear hsync
                hsync_reg <= LOW ;
                // State transition
                h_state <= (h_counter == H_PULSE)?H_BACK_STATE:H_PULSE_STATE ;
            end
            if (h_state == H_BACK_STATE) begin
                // Iterate horizontal counter, zero at end of H_BACK mode
                h_counter <= (h_counter==H_BACK)?10'd0:(h_counter + 10'd1) ;
                // Set hsync
                hsync_reg <= HIGH ;
                // State transition
                h_state <= (h_counter == H_BACK)?H_ACTIVE_STATE:H_BACK_STATE ;
                // Signal line complete at state transition (offset by 1 for synchronous state transition)
                line_done <= (h_counter == (H_BACK-1))?HIGH:LOW ;
            end
            //////////////////////////////////////////////////////////////////////////
            ///////////////////////// VERTICAL ///////////////////////////////////////
            //////////////////////////////////////////////////////////////////////////
            if (v_state == V_ACTIVE_STATE) begin
                // increment vertical counter at end of line, zero on state transition
                v_counter <= (line_done==HIGH)?((v_counter==V_ACTIVE)?10'd0:(v_counter+10'd1)):v_counter ;
                // set vsync in active mode
                vsync_reg <= HIGH ;
                // state transition - only on end of lines
                v_state<=(line_done==HIGH)?((v_counter==V_ACTIVE)?V_FRONT_STATE:V_ACTIVE_STATE):V_ACTIVE_STATE ;
            end
            if (v_state == V_FRONT_STATE) begin
                // increment vertical counter at end of line, zero on state transition
                v_counter<=(line_done==HIGH)?((v_counter==V_FRONT)?10'd0:(v_counter + 10'd1)):v_counter ;
                // set vsync in front porch
                vsync_reg <= HIGH ;
                // state transition
                v_state<=(line_done==HIGH)?((v_counter==V_FRONT)?V_PULSE_STATE:V_FRONT_STATE):V_FRONT_STATE;
            end
            if (v_state == V_PULSE_STATE) begin
                // increment vertical counter at end of line, zero on state transition
                v_counter<=(line_done==HIGH)?((v_counter==V_PULSE)?10'd0:(v_counter + 10'd1)):v_counter ;
                // clear vsync in pulse
                vsync_reg <= LOW ;
                // state transition
                v_state<=(line_done==HIGH)?((v_counter==V_PULSE)?V_BACK_STATE:V_PULSE_STATE):V_PULSE_STATE;
            end
            if (v_state == V_BACK_STATE) begin
                // increment vertical counter at end of line, zero on state transition
                v_counter<=(line_done==HIGH)?((v_counter==V_BACK)?10'd0:(v_counter + 10'd1)):v_counter ;
                // set vsync in back porch
                vsync_reg <= HIGH ;
                // state transition
                v_state<=(line_done==HIGH)?((v_counter==V_BACK)?V_ACTIVE_STATE:V_BACK_STATE):V_BACK_STATE ;
            end

            //////////////////////////////////////////////////////////////////////////
            //////////////////////////////// COLOR OUT ///////////////////////////////
            //////////////////////////////////////////////////////////////////////////
            // Assign colors if in active mode
            red_reg   <= (h_state==H_ACTIVE_STATE && v_state==V_ACTIVE_STATE) ? color_in[11:8] : 4'b0000;
            green_reg <= (h_state==H_ACTIVE_STATE && v_state==V_ACTIVE_STATE) ? color_in[ 7:4] : 4'b0000;
            blue_reg  <= (h_state==H_ACTIVE_STATE && v_state==V_ACTIVE_STATE) ? color_in[ 3:0] : 4'b0000;

        end
    end
    // Assign output values - to VGA connector
    assign hsync = hsync_reg;
    assign vsync = vsync_reg;
    assign vga_red = red_reg;
    assign vga_green = green_reg;
    assign vga_blue = blue_reg;
    assign sync = hsync_reg & vsync_reg;
    assign blank = h_state == H_ACTIVE_STATE && v_state == V_ACTIVE_STATE;
    assign next_x = (h_state==H_ACTIVE_STATE)?h_counter:10'd0;
    assign next_y = (v_state==V_ACTIVE_STATE)?v_counter:10'd0;

endmodule