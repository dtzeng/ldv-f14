/*********************************************
 *  18-341 Fall 2014                         *
 *  Updated 09/11/14 3:40pm                  *
 *  Project 2                                *
 *  Network-on-Chip node                     *
 *********************************************/

module node(clk, rst_b, pkt_in, pkt_in_avail, cQ_full, pkt_out, pkt_out_avail,
            free_outbound, put_outbound, payload_outbound,
            free_inbound, put_inbound, payload_inbound);

   parameter NODEID = 0;
   input clk, rst_b;

   // Interface to TestBench
   input pkt_t pkt_in;
   input pkt_in_avail;
   output cQ_full;
   output pkt_t pkt_out;
   output logic pkt_out_avail;

   // Endpoint -> Router transaction
   input 	free_outbound; // Router -> Endpoint
   output logic put_outbound; // Endpoint -> Router
   output [7:0] payload_outbound;

   // Router -> Endpoint transaction
   output logic free_inbound; // Endpoint -> Router
   input 	put_inbound; // Router -> Endpoint
   input [7:0] 	payload_inbound;


   logic 	queue_we, queue_re, queue_empty;
   logic [31:0] queue_out;

   logic 	cl_to_router, inc_to_router;
   logic [1:0] 	sel_to_router;
   logic 	ld_ob, sel_ob_in;
   logic [31:0] ob_in;
   logic 	ld_ob_full, cl_ob_full, ob_full;

   logic 	cl_from_router, inc_from_router;
   logic [1:0] 	sel_from_router;
   logic 	ld_ib, ld_ib_free, cl_ib_free;

   enum 	logic [1:0] {s1 = 2'b00, s2 = 2'b01, s3 = 2'b10, s4 = 2'b11} ob_CS, ob_NS, ib_CS, ib_NS;

   fifo queue (.clk(clk), .rst_b(rst_b), .data_in(pkt_in), .we(queue_we), .re(queue_re),
	       .full(cQ_full), .empty(queue_empty), .data_out(queue_out));
   
   assign ob_in = sel_ob_in ? pkt_in : queue_out;
   
   counter #(2) to_router (.clk(clk), .rst_b(rst_b), .cl(cl_to_router), .inc(inc_to_router),
			   .dec(1'b0), .Q(sel_to_router));
   reg32to8 output_buffer (.clk(clk), .rst_b(rst_b), .ld(ld_ob), .cl(1'b0), .sel(sel_to_router),
			   .D(ob_in), .Q(payload_outbound));
   register #(1) output_buffer_full (.clk(clk), .rst_b(rst_b), .ld(ld_ob_full), .cl(cl_ob_full),
				     .D(1'b1), .Q(ob_full));
   

   /* Thread dealing with the queue (one state) */
   always_comb begin
      sel_ob_in = 0; ld_ob = 0; ld_ob_full = 0; queue_we = 0; queue_re = 0;
      if(pkt_in_avail && queue_empty && !ob_full) begin
	 sel_ob_in = 1; ld_ob = 1; ld_ob_full = 1;
      end
      else if(pkt_in_avail) begin
	 queue_we = 1;
      end
      else if(!pkt_in_avail && !queue_empty && !ob_full) begin
	 ld_ob = 1; ld_ob_full = 1; queue_re = 1;
      end
   end // always_comb begin

   
   /* Thread dealing with output buffer to router */
   always_ff @(posedge clk, negedge rst_b) begin: output_buffer_fsm
      if(~rst_b)
	ob_CS <= s1;
      else
	ob_CS <= ob_NS;
   end: output_buffer_fsm

   always_comb begin
      cl_to_router = 0; inc_to_router = 0; cl_ob_full = 0; put_outbound = 0;
      case(ob_CS)
	s1: begin
	   if(!(ob_full && free_outbound)) begin
	      ob_NS = s1;
	   end
	   else begin
	      put_outbound = 1; inc_to_router = 1;
	      ob_NS = s2;
	   end
	end
	
	s2: begin
	   if(sel_to_router != 2'd3) begin
	      put_outbound = 1; inc_to_router = 1;
	      ob_NS = s2;
	   end
	   else begin
	      put_outbound = 1; cl_to_router = 1; cl_ob_full = 1;
	      ob_NS = s1;
	   end
	end
      endcase // case (ob_CS)
   end
   
   
   counter #(2) from_router(.clk(clk), .rst_b(rst_b), .cl(cl_from_router), .inc(inc_from_router),
			    .dec(1'b0), .Q(sel_from_router));
   reg8to32 input_buffer (.clk(clk), .rst_b(rst_b), .ld(ld_ib), .cl(1'b0), .sel(sel_from_router),
			  .D(payload_inbound), .Q(pkt_out));
   register #(1, 1) input_buffer_free (.clk(clk), .rst_b(rst_b),
				       .ld(ld_ib_free), .cl(cl_ib_free),
				       .D(1'b1), .Q(free_inbound));

   /* Thread dealing with router to input buffer */
   always_ff @(posedge clk, negedge rst_b) begin: input_buffer_fsm
      if(~rst_b) begin
	 ib_CS <= s1;
      end
      else begin
	 ib_CS <= ib_NS;
      end
   end: input_buffer_fsm

   always_comb begin
      pkt_out_avail = 0;
      cl_from_router = 0; inc_from_router = 0; ld_ib = 0; ld_ib_free = 0; cl_ib_free = 0;
      case(ib_CS)
	s1: begin
	   if(!put_inbound) begin
	      ib_NS = s1;
	   end
	   else begin
	      ld_ib = 1; inc_from_router = 1; cl_ib_free = 1;
	      ib_NS = s2;
	   end
	end

	s2: begin
	   if(sel_from_router != 2'd3) begin
	      ld_ib = 1; inc_from_router = 1;
	      ib_NS = s2;
	   end
	   else begin
	      ld_ib = 1; cl_from_router = 1;
	      ib_NS = s3;
	   end
	end

	s3: begin
	   pkt_out_avail = 1; ld_ib_free = 1;
	   ib_NS = s1;
	end
      endcase // case (ib_CS)
   end

endmodule

/*  Create a fifo (First In First Out) with depth 4 using the given interface
 *  and constraints.
 *  -The fifo is initally empty.
 *  -Reads are combinational, so "data_out" is valid unless "empty" is asserted.
 *   Removal from the queue is processed on the clock edge.
 *  -Writes are processed on the clock edge.  
 *  -If the "we" happens to be asserted while the fifo is full, do NOT update
 *   the fifo.
 *  -Similarly, if the "re" is asserted while the fifo is empty, do NOT update
 *   the fifo. 
 */

module fifo(clk, rst_b, data_in, we, re, full, empty, data_out);
   parameter WIDTH = 32;
   input clk, rst_b;
   input [WIDTH-1:0] data_in;
   input 	     we; //write enable
   input 	     re; //read enable
   output 	     full;
   output 	     empty;
   output [WIDTH-1:0] data_out;

   
   bit [3:0][WIDTH-1:0] queue;
   bit [1:0] 		putPtr, getPtr;
   bit [2:0] 		count;

   assign full = (count == 3'd4);
   assign empty = (count == 3'd0);
   assign data_out = queue[getPtr];

   always_ff @(posedge clk, negedge rst_b) begin
      if(~rst_b) begin
	 count <= 0;
	 putPtr <= 0;
	 getPtr <= 0;
      end
      else begin
	 if(we && (!full)) begin
	    queue[putPtr] <= data_in;
	    putPtr <= putPtr + 1;
	    count <= count + 1;
	 end
	 else if(re && (!empty)) begin
	    getPtr <= getPtr + 1;
	    count <= count - 1;
	 end
      end
   end

endmodule // fifo

module register
  #(parameter W = 32, R = 0)
   (input logic clk, rst_b, ld, cl,
    input logic [W-1:0] D,
    output logic [W-1:0] Q);

   always_ff @(posedge clk, negedge rst_b) begin
      if(~rst_b)
	Q <= R;
      else if(cl)
	Q <= 'b0;
      else if(ld)
	Q <= D;
   end

endmodule: register

module counter
  #(parameter W = 32)
   (input logic clk, rst_b, cl, inc, dec,
    output logic [W-1:0] Q);

   always_ff @(posedge clk, negedge rst_b) begin
      if(~rst_b)
	Q <= 'b0;
      else if(cl)
	Q <= 'b0;
      else if(inc)
	Q <= Q + 1;
      else if(dec)
	Q <= Q - 1;
   end

endmodule: counter


module reg8to32
  (input logic clk, rst_b, ld, cl,
   input logic [1:0] sel,
   input logic [7:0] D,
   output logic [31:0] Q);

   always_ff @(posedge clk, negedge rst_b) begin
      if(~rst_b)
	Q <= 32'b0;
      else if(cl)
	Q <= 32'b0;
      else if(ld && (sel == 2'b11))
	Q[7:0] <= D;
      else if(ld && (sel == 2'b10))
	Q[15:8] <= D;
      else if(ld && (sel == 2'b01))
	Q[23:16] <= D;
      else if(ld && (sel == 2'b00))
	Q[31:24] <= D;
   end

endmodule: reg8to32

module reg32to8
  (input logic clk, rst_b, ld, cl,
   input logic [1:0] sel,
   input logic [31:0] D,
   output logic [7:0] Q);

   logic [31:0]       register;
   
   always_comb begin
      if(sel == 2'b11)
	Q = register[7:0];
      else if(sel == 2'b10)
	Q = register[15:8];
      else if(sel == 2'b01)
	Q = register[23:16];
      else
	Q = register[31:24];
   end
   

   always_ff @(posedge clk, negedge rst_b) begin
      if(~rst_b)
	register <= 32'b0;
      else if(cl)
	register <= 32'b0;
      else if(ld)
	register <= D;
   end

endmodule: reg32to8
