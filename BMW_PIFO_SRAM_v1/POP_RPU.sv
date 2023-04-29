`timescale 1ns / 10ps
/*-----------------------------------------------------------------------------

Proprietary and Confidential Information

Module: PIFO_SRAM.v
Author: Zhiyu Zhang
Date  : 03/10/2023

Description: Instead of using FFs to implement PIFO, this module uses SRAM
             so that the whole PIFO tree can be extended to more layers. 
			 
Issues:  

-----------------------------------------------------------------------------*/

//-----------------------------------------------------------------------------
// Module Port Definition
//-----------------------------------------------------------------------------
module POP_RPU 
#(
   parameter PTW  = 16,  // Payload data width
   parameter MTW  = 0,  // Metdata width
   parameter CTW  = 10,  // Counter width
   parameter ADW  = 20   // Address width
)(
   // Clock and Reset
   input                          i_clk,         // I - Clock
   input                          i_arst_n,      // I - Active Low Async Reset

   output[1:0]                    o_fsm,         // O - fsm state
  
   // From/To Parent    
   input                          i_pop,         // I - Pop Command from Parent
   output [(MTW+PTW)-1:0]         o_pop_data,    // O - Pop Data from Parent
   
   // From/To Child
   
   output                         o_pop,         // O - Pop Command to Child   
   input  [(MTW+PTW)-1:0]         i_pop_data,    // I - Pop Data from Child
   
   // From/To SRAM
   output                         o_read,        // O - SRAM Read
   input  [4*(CTW+MTW+PTW)-1:0]   i_read_data,   // I - SRAM Read Data {sub_tree_size3,pifo_val3,sub_tree_size2,pifo_val2,sub_tree_size1,pifo_val1,sub_tree_size0,pifo_val0}
   
   output                         o_write,       // O - SRAM Write
   output [4*(CTW+MTW+PTW)-1:0]   o_write_data,  // O - SRAM Write Data {sub_tree_size3,pifo_val3,sub_tree_size2,pifo_val2,sub_tree_size1,pifo_val1,sub_tree_size0,pifo_val0}

   input  [ADW-1:0]               i_my_addr,
   output [ADW-1:0]               o_child_addr,

   output [ADW-1:0]               o_read_addr,
   output [ADW-1:0]               o_write_addr
);

//-----------------------------------------------------------------------------
// Include Files
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------------------
localparam    ST_IDLE     = 2'b00,
              ST_POP      = 2'b11,
	 	 	     ST_WB       = 2'b10;

//-----------------------------------------------------------------------------
// Register and Wire Declarations
//-----------------------------------------------------------------------------
   // State Machine
   reg [1:0]             fsm;
   
   // SRAM Read/Write   
   wire                  read;
   reg                   write;
   reg [4*(CTW+MTW+PTW)-1:0] wdata;

      
   reg                   pop;
   reg [(MTW+PTW)-1:0]         pop_data;   
	  
   reg [1:0]             min_sub_tree;
   reg [1:0]             min_data_port;

	//for parent/child node
   reg [ADW-1:0]         my_addr;
   reg [ADW-1:0]         child_addr;
   
   

   
   

     
//-----------------------------------------------------------------------------
// Instantiations
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
// Functions and Tasks
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Sequential Logic
//-----------------------------------------------------------------------------
always @ (posedge i_clk or negedge i_arst_n)
   begin
      if (!i_arst_n) begin
         fsm     <= ST_IDLE;
         push_data <= 'd0;	
		   my_addr      <= 'd0;

      end else begin
	     case (fsm)
            ST_IDLE: begin
                if (i_pop) begin
                     fsm    <= ST_POP;
					      my_addr      <= i_my_addr;
                end else begin
                     fsm    <= ST_IDLE;
					      my_addr      <= 'd0;
                end
            end  
            ST_POP: begin
               my_addr      <= my_addr;
               fsm          <= ST_WB;
            end		  
            ST_WB: begin
                  if (i_pop) begin
                        fsm    <= ST_POP;
                        my_addr      <= i_my_addr;
                  end else begin
                        fsm    <= ST_IDLE;
                        my_addr      <= 'd0;
                  end
            end			
 	     endcase
      end	  
   end
   
//-----------------------------------------------------------------------------
// Combinatorial Logic / Continuous Assignments
//-----------------------------------------------------------------------------
always @ *
   begin
      if (fsm == ST_POP || fsm == ST_WB) begin
         case (min_data_port[1:0])
            2'b00: begin
               pop           = 1'b1;
               pop_data      = i_read_data[(MTW+PTW)-1:0];
               write         = 1'b1;
               child_addr    = 4 * my_addr + 0;
		  	   if (i_read_data[(MTW+PTW+CTW)-1:(MTW+PTW)] != 0) begin
                  wdata      = {i_read_data[4*(CTW+MTW+PTW)-1:(CTW+MTW+PTW)], i_read_data[(CTW+MTW+PTW)-1:(MTW+PTW)]-{{(CTW-1){1'b0}},1'b1}, i_pop_data};
			   end else begin
                  wdata      = i_read_data[4*(CTW+MTW+PTW)-1:0];
            end						   
            end
            2'b01: begin
               pop           = 1'b1;
               pop_data      = i_read_data[2*(MTW+PTW)+CTW-1:(CTW+MTW+PTW)];
               write         = 1'b1;
               child_addr    = 4 * my_addr + 1;
			   if (i_read_data[2*(MTW+PTW+CTW)-1:2*(MTW+PTW)+CTW] != 0) begin
                  wdata      = {i_read_data[4*(CTW+MTW+PTW)-1:2*(CTW+MTW+PTW)], i_read_data[2*(CTW+MTW+PTW)-1:2*(MTW+PTW)+CTW]-{{(CTW-1){1'b0}},1'b1}, i_pop_data, i_read_data[(MTW+PTW+CTW)-1:0]};
	  		   end else begin
                  wdata      = i_read_data[4*(CTW+MTW+PTW)-1:0];
            end						   
            end
            2'b10: begin
	   	      pop           = 1'b1;
               pop_data      = i_read_data[3*(MTW+PTW)+2*CTW-1:2*(CTW+MTW+PTW)];
               write         = 1'b1;
               child_addr    = 4 * my_addr + 2;
			   if (i_read_data[3*(MTW+PTW+CTW)-1:3*(MTW+PTW)+2*CTW] != 0) begin
                  wdata      = {i_read_data[4*(CTW+MTW+PTW)-1:3*(CTW+MTW+PTW)], i_read_data[3*(CTW+MTW+PTW)-1:3*(MTW+PTW)+2*CTW]-{{(CTW-1){1'b0}},1'b1}, i_pop_data, i_read_data[2*(MTW+PTW+CTW)-1:0]};
			   end else begin
                  wdata      = i_read_data[4*(CTW+MTW+PTW)-1:0];
            end						   
            end
            2'b11: begin
	   	      pop           = 1'b1;
               pop_data      = i_read_data[4*(MTW+PTW)+3*CTW-1:3*(CTW+MTW+PTW)];
   		      write         = 1'b1;
			      child_addr    = 4 * my_addr + 3;
			   if (i_read_data[4*(MTW+PTW+CTW)-1:4*(MTW+PTW)+3*CTW] != 0) begin
                  wdata      = {i_read_data[4*(CTW+MTW+PTW)-1:4*(MTW+PTW)+3*CTW]-{{(CTW-1){1'b0}},1'b1}, i_pop_data, i_read_data[3*(MTW+PTW+CTW)-1:0]};
			   end else begin
                  wdata      = i_read_data[4*(CTW+MTW+PTW)-1:0];
            end						   
            end		 
         endcase	  		
      end else begin
         write       = 1'b0;
         wdata       = 'd0;         
         pop         = 1'b0;                 
         pop_data    = -'d1;
         child_addr  = -'d1;
      end	  
   end
   
always @ *
   begin
      // Find the minimum sub-tree. 
      if (i_read_data[(CTW+MTW+PTW)-1:(MTW+PTW)] <= i_read_data[2*(CTW+MTW+PTW)-1:2*(MTW+PTW)+CTW] &&
	      i_read_data[(CTW+MTW+PTW)-1:(MTW+PTW)] <= i_read_data[3*(CTW+MTW+PTW)-1:3*(MTW+PTW)+2*CTW] &&
		  i_read_data[(CTW+MTW+PTW)-1:(MTW+PTW)] <= i_read_data[4*(CTW+MTW+PTW)-1:4*(MTW+PTW)+3*CTW]) begin
	     min_sub_tree[1:0] = 2'b00;	  
      end else if (i_read_data[2*(CTW+MTW+PTW)-1:2*(MTW+PTW)+CTW] <= i_read_data[(CTW+MTW+PTW)-1:(MTW+PTW)] &&
	      i_read_data[2*(CTW+MTW+PTW)-1:2*(MTW+PTW)+CTW] <= i_read_data[3*(CTW+MTW+PTW)-1:3*(MTW+PTW)+2*CTW] &&
		  i_read_data[2*(CTW+MTW+PTW)-1:2*(MTW+PTW)+CTW] <= i_read_data[4*(CTW+MTW+PTW)-1:4*(MTW+PTW)+3*CTW]) begin
	     min_sub_tree[1:0] = 2'b01;	  
      end else if (i_read_data[3*(CTW+MTW+PTW)-1:3*(MTW+PTW)+2*CTW] <= i_read_data[(CTW+MTW+PTW)-1:(MTW+PTW)] &&
	      i_read_data[3*(CTW+MTW+PTW)-1:3*(MTW+PTW)+2*CTW] <= i_read_data[2*(CTW+MTW+PTW)-1:2*(MTW+PTW)+CTW] &&
		  i_read_data[3*(CTW+MTW+PTW)-1:3*(MTW+PTW)+2*CTW] <= i_read_data[4*(CTW+MTW+PTW)-1:4*(MTW+PTW)+3*CTW]) begin
	     min_sub_tree[1:0] = 2'b10;
      end else begin
	     min_sub_tree[1:0] = 2'b11;
      end		 
	  
      // Find the minimum data and minimum data port.
      if (i_read_data[PTW-1:0] <= i_read_data[2*PTW+(CTW+MTW)-1:(CTW+MTW+PTW)] &&
	      i_read_data[PTW-1:0] <= i_read_data[3*PTW+2*(CTW+MTW)-1:2*(CTW+MTW+PTW)] &&
		  i_read_data[PTW-1:0] <= i_read_data[4*PTW+3*(CTW+MTW)-1:3*(CTW+MTW+PTW)]) begin
		 min_data_port[1:0]  = 2'b00;
      end else if (i_read_data[2*PTW+(CTW+MTW)-1:(CTW+MTW+PTW)] <= i_read_data[PTW-1:0] &&
	      i_read_data[2*PTW+(CTW+MTW)-1:(CTW+MTW+PTW)] <= i_read_data[3*PTW+2*(CTW+MTW)-1:2*(CTW+MTW+PTW)] &&
		  i_read_data[2*PTW+(CTW+MTW)-1:(CTW+MTW+PTW)] <= i_read_data[4*PTW+3*(CTW+MTW)-1:3*(CTW+MTW+PTW)]) begin
		 min_data_port[1:0]  = 2'b01;
 	  end else if (i_read_data[3*PTW+2*(CTW+MTW)-1:2*(CTW+MTW+PTW)] <= i_read_data[PTW-1:0] &&
	      i_read_data[3*PTW+2*(CTW+MTW)-1:2*(CTW+MTW+PTW)] <= i_read_data[2*PTW+(CTW+MTW)-1:(CTW+MTW+PTW)] &&
		  i_read_data[3*PTW+2*(CTW+MTW)-1:2*(CTW+MTW+PTW)] <= i_read_data[4*PTW+3*(CTW+MTW)-1:3*(CTW+MTW+PTW)]) begin
		 min_data_port[1:0]  = 2'b10;
 	  end else begin
		 min_data_port[1:0]  = 2'b11;
      end		 		  	  
   end

//-----------------------------------------------------------------------------
// Continous Assignments
//-----------------------------------------------------------------------------
   assign read = (i_pop) & (fsm == ST_IDLE | fsm == ST_WB);
   
   
      
//-----------------------------------------------------------------------------
// Output Assignments
//-----------------------------------------------------------------------------
   assign o_fsm = fsm;

   assign o_read_addr   = i_my_addr;
   assign o_write_addr  = my_addr;

   assign o_read        = read;
   assign o_write       = write;
   assign o_write_data  = wdata;
   
   assign o_pop         = pop;
   
   assign o_pop_data    = pop_data;
   assign o_child_addr  = child_addr;

endmodule
