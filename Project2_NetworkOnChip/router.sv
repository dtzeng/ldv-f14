/*********************************************
 *  18-341 Fall 2014                         *
 *  Project 2                                *
 *  Network-on-Chip node                     *
 *********************************************/

/*
 * A router transfers packets between nodes and other routers.
 */
module router(clk, rst_b,
              free_outbound, put_outbound, payload_outbound,
              free_inbound, put_inbound, payload_inbound);
   parameter ROUTERID = 0; // To differentiate between routers
   input  clk, rst_b;

   // self -> destination (sending a payload)
   input [3:0] free_outbound;
   output [3:0] put_outbound;
   output [3:0][7:0] payload_outbound;

   // source -> self (receiving a payload)
   output [3:0]      free_inbound;
   input [3:0] 	     put_inbound;
   input [3:0][7:0]  payload_inbound;

   /* Thread dealing with loading from inbound */
   logic 	     ld_p0_in_free, ld_p1_in_free, ld_p2_in_free, ld_p3_in_free;
   logic 	     cl_p0_in_free, cl_p1_in_free, cl_p2_in_free, cl_p3_in_free;

   register #(1, 1) port0_in_free (.clk(clk), .rst_b(rst_b),
				   .ld(ld_p0_in_free), .cl(cl_p0_in_free),
				   .D(1'b1), .Q(free_inbound[0]));
   register #(1, 1) port1_in_free (.clk(clk), .rst_b(rst_b),
				   .ld(ld_p1_in_free), .cl(cl_p1_in_free),
				   .D(1'b1), .Q(free_inbound[1]));
   register #(1, 1) port2_in_free (.clk(clk), .rst_b(rst_b),
				   .ld(ld_p2_in_free), .cl(cl_p2_in_free),
				   .D(1'b1), .Q(free_inbound[2]));
   register #(1, 1) port3_in_free (.clk(clk), .rst_b(rst_b),
				   .ld(ld_p3_in_free), .cl(cl_p3_in_free),
				   .D(1'b1), .Q(free_inbound[3]));

   logic 	     ld_p0_in_valid, ld_p1_in_valid, ld_p2_in_valid, ld_p3_in_valid;
   logic 	     cl_p0_in_valid, cl_p1_in_valid, cl_p2_in_valid, cl_p3_in_valid;
   logic 	     p0_in_valid, p1_in_valid, p2_in_valid, p3_in_valid;
   
   register #(1) port0_in_valid (.clk(clk), .rst_b(rst_b),
				 .ld(ld_p0_in_valid), .cl(cl_p0_in_valid),
				 .D(1'b1), .Q(p0_in_valid));
   register #(1) port1_in_valid (.clk(clk), .rst_b(rst_b),
				 .ld(ld_p1_in_valid), .cl(cl_p1_in_valid),
				 .D(1'b1), .Q(p1_in_valid));
   register #(1) port2_in_valid (.clk(clk), .rst_b(rst_b),
				 .ld(ld_p2_in_valid), .cl(cl_p2_in_valid),
				 .D(1'b1), .Q(p2_in_valid));
   register #(1) port3_in_valid (.clk(clk), .rst_b(rst_b),
				 .ld(ld_p3_in_valid), .cl(cl_p3_in_valid),
				 .D(1'b1), .Q(p3_in_valid));

   logic 	     ld_p0_in, ld_p1_in, ld_p2_in, ld_p3_in;
   logic [1:0] 	     sel_p0_in, sel_p1_in, sel_p2_in, sel_p3_in;
   logic [31:0]      p0_in, p1_in, p2_in, p3_in;
   
   reg8to32 port0_in (.clk(clk), .rst_b(rst_b), .ld(ld_p0_in), .cl(1'b0), .sel(sel_p0_in),
		      .D(payload_inbound[0]), .Q(p0_in));
   reg8to32 port1_in (.clk(clk), .rst_b(rst_b), .ld(ld_p1_in), .cl(1'b0), .sel(sel_p1_in),
		      .D(payload_inbound[1]), .Q(p1_in));
   reg8to32 port2_in (.clk(clk), .rst_b(rst_b), .ld(ld_p2_in), .cl(1'b0), .sel(sel_p2_in),
		      .D(payload_inbound[2]), .Q(p2_in));
   reg8to32 port3_in (.clk(clk), .rst_b(rst_b), .ld(ld_p3_in), .cl(1'b0), .sel(sel_p3_in),
		      .D(payload_inbound[3]), .Q(p3_in));

   fsm_load_in load_port0_in (.clk(clk), .rst_b(rst_b), .put(put_inbound[0]),
			      .ld(ld_p0_in), .cl_free(cl_p0_in_free), .ld_valid(ld_p0_in_valid),
			      .count(sel_p0_in));
   fsm_load_in load_port1_in (.clk(clk), .rst_b(rst_b), .put(put_inbound[1]),
			      .ld(ld_p1_in), .cl_free(cl_p1_in_free), .ld_valid(ld_p1_in_valid),
			      .count(sel_p1_in));
   fsm_load_in load_port2_in (.clk(clk), .rst_b(rst_b), .put(put_inbound[2]),
			      .ld(ld_p2_in), .cl_free(cl_p2_in_free), .ld_valid(ld_p2_in_valid),
			      .count(sel_p2_in));
   fsm_load_in load_port3_in (.clk(clk), .rst_b(rst_b), .put(put_inbound[3]),
			      .ld(ld_p3_in), .cl_free(cl_p3_in_free), .ld_valid(ld_p3_in_valid),
			      .count(sel_p3_in));
   


   /* Thread dealing with writing to outbound */
   logic 	     ld_p0_out_full, ld_p1_out_full, ld_p2_out_full, ld_p3_out_full;
   logic 	     cl_p0_out_full, cl_p1_out_full, cl_p2_out_full, cl_p3_out_full;
   logic 	     p0_out_full, p1_out_full, p2_out_full, p3_out_full;
   
   register #(1) port0_out_full (.clk(clk), .rst_b(rst_b),
				 .ld(ld_p0_out_full), .cl(cl_p0_out_full),
				 .D(1'b1), .Q(p0_out_full));
   register #(1) port1_out_full (.clk(clk), .rst_b(rst_b),
				 .ld(ld_p1_out_full), .cl(cl_p1_out_full),
				 .D(1'b1), .Q(p1_out_full));
   register #(1) port2_out_full (.clk(clk), .rst_b(rst_b),
				 .ld(ld_p2_out_full), .cl(cl_p2_out_full),
				 .D(1'b1), .Q(p2_out_full));
   register #(1) port3_out_full (.clk(clk), .rst_b(rst_b),
				 .ld(ld_p3_out_full), .cl(cl_p3_out_full),
				 .D(1'b1), .Q(p3_out_full));

   logic 	     ld_p0_out, ld_p1_out, ld_p2_out, ld_p3_out;
   logic [1:0] 	     sel_p0_out, sel_p1_out, sel_p2_out, sel_p3_out;
   logic [31:0]      p0_out_D, p1_out_D, p2_out_D, p3_out_D;
   
   reg32to8 port0_out (.clk(clk), .rst_b(rst_b), .ld(ld_p0_out), .cl(1'b0), .sel(sel_p0_out),
		       .D(p0_out_D), .Q(payload_outbound[0]));
   reg32to8 port1_out (.clk(clk), .rst_b(rst_b), .ld(ld_p1_out), .cl(1'b0), .sel(sel_p1_out),
		       .D(p1_out_D), .Q(payload_outbound[1]));
   reg32to8 port2_out (.clk(clk), .rst_b(rst_b), .ld(ld_p2_out), .cl(1'b0), .sel(sel_p2_out),
		       .D(p2_out_D), .Q(payload_outbound[2]));
   reg32to8 port3_out (.clk(clk), .rst_b(rst_b), .ld(ld_p3_out), .cl(1'b0), .sel(sel_p3_out),
		       .D(p3_out_D), .Q(payload_outbound[3]));

   fsm_write_out write_port0_out (.clk(clk), .rst_b(rst_b), .full(p0_out_full), .free_out(free_outbound[0]),
				  .put_out(put_outbound[0]), .cl_full(cl_p0_out_full), .count(sel_p0_out));
   fsm_write_out write_port1_out (.clk(clk), .rst_b(rst_b), .full(p1_out_full), .free_out(free_outbound[1]),
				  .put_out(put_outbound[1]), .cl_full(cl_p1_out_full), .count(sel_p1_out));
   fsm_write_out write_port2_out (.clk(clk), .rst_b(rst_b), .full(p2_out_full), .free_out(free_outbound[2]),
				  .put_out(put_outbound[2]), .cl_full(cl_p2_out_full), .count(sel_p2_out));
   fsm_write_out write_port3_out (.clk(clk), .rst_b(rst_b), .full(p3_out_full), .free_out(free_outbound[3]),
				  .put_out(put_outbound[3]), .cl_full(cl_p3_out_full), .count(sel_p3_out));

   /* Thread dealing with routing logic */
   logic [1:0] 	     sel_to_p0, sel_to_p1, sel_to_p2, sel_to_p3;
   mux3to1 to_port0 (.A(p1_in), .B(p2_in), .C(p3_in), .sel(sel_to_p0), .out(p0_out_D));
   mux3to1 to_port1 (.A(p2_in), .B(p3_in), .C(p0_in), .sel(sel_to_p1), .out(p1_out_D));
   mux3to1 to_port2 (.A(p3_in), .B(p0_in), .C(p1_in), .sel(sel_to_p2), .out(p2_out_D));
   mux3to1 to_port3 (.A(p0_in), .B(p1_in), .C(p2_in), .sel(sel_to_p3), .out(p3_out_D));

   logic [2:0][3:0]  dests_to_p0, dests_to_p1, dests_to_p2, dests_to_p3;
   assign dests_to_p0 = {p3_in[27:24], p2_in[27:24], p1_in[27:24]};
   assign dests_to_p1 = {p0_in[27:24], p3_in[27:24], p2_in[27:24]};
   assign dests_to_p2 = {p1_in[27:24], p0_in[27:24], p3_in[27:24]};
   assign dests_to_p3 = {p2_in[27:24], p1_in[27:24], p0_in[27:24]};

   logic [2:0] 	     valids_to_p0, valids_to_p1, valids_to_p2, valids_to_p3;
   assign valids_to_p0 = {p3_in_valid, p2_in_valid, p1_in_valid};
   assign valids_to_p1 = {p0_in_valid, p3_in_valid, p2_in_valid};
   assign valids_to_p2 = {p1_in_valid, p0_in_valid, p3_in_valid};
   assign valids_to_p3 = {p2_in_valid, p1_in_valid, p0_in_valid};

   logic 	     inc_p0_round0, inc_p1_round0, inc_p2_round0, inc_p3_round0;
   logic [1:0] 	     p0_round0, p0_round1, p0_round2;
   logic [1:0] 	     p1_round0, p1_round1, p1_round2;
   logic [1:0] 	     p2_round0, p2_round1, p2_round2;
   logic [1:0] 	     p3_round0, p3_round1, p3_round2;
   countto2 round_to_port0 (.clk(clk), .rst_b(rst_b), .cl(1'b0), .inc(inc_p0_round0), .Q(p0_round0));
   countto2 round_to_port1 (.clk(clk), .rst_b(rst_b), .cl(1'b0), .inc(inc_p1_round0), .Q(p1_round0));
   countto2 round_to_port2 (.clk(clk), .rst_b(rst_b), .cl(1'b0), .inc(inc_p2_round0), .Q(p2_round0));
   countto2 round_to_port3 (.clk(clk), .rst_b(rst_b), .cl(1'b0), .inc(inc_p3_round0), .Q(p3_round0));

   assign p0_round1 = p0_round0 == 2'd2 ? 2'd0 : p0_round0 + 1;
   assign p0_round2 = p0_round0 == 2'd2 ? 2'd1 : (p0_round0 == 2'd1 ? 2'd0 : 2'd2);
   
   assign p1_round1 = p1_round0 == 2'd2 ? 2'd0 : p1_round0 + 1;
   assign p1_round2 = p1_round0 == 2'd2 ? 2'd1 : (p1_round0 == 2'd1 ? 2'd0 : 2'd2);
   
   assign p2_round1 = p2_round0 == 2'd2 ? 2'd0 : p2_round0 + 1;
   assign p2_round2 = p2_round0 == 2'd2 ? 2'd1 : (p2_round0 == 2'd1 ? 2'd0 : 2'd2);
   
   assign p3_round1 = p3_round0 == 2'd2 ? 2'd0 : p3_round0 + 1;
   assign p3_round2 = p3_round0 == 2'd2 ? 2'd1 : (p3_round0 == 2'd1 ? 2'd0 : 2'd2);

   logic 	     ready_to_p0, ready_to_p1, ready_to_p2, ready_to_p3;
   logic 	     ld_p0_in_free1, ld_p0_in_free2, ld_p0_in_free3,
		     ld_p1_in_free0, ld_p1_in_free2, ld_p1_in_free3,
		     ld_p2_in_free0, ld_p2_in_free1, ld_p2_in_free3,
		     ld_p3_in_free0, ld_p3_in_free1, ld_p3_in_free2;
   logic 	     cl_p0_in_valid1, cl_p0_in_valid2, cl_p0_in_valid3,
		     cl_p1_in_valid0, cl_p1_in_valid2, cl_p1_in_valid3,
		     cl_p2_in_valid0, cl_p2_in_valid1, cl_p2_in_valid3,
		     cl_p3_in_valid0, cl_p3_in_valid1, cl_p3_in_valid2;

   assign ld_p0_in_free = ld_p0_in_free1 | ld_p0_in_free2 | ld_p0_in_free3;
   assign ld_p1_in_free = ld_p1_in_free0 | ld_p1_in_free2 | ld_p1_in_free3;
   assign ld_p2_in_free = ld_p2_in_free0 | ld_p2_in_free1 | ld_p2_in_free3;
   assign ld_p3_in_free = ld_p3_in_free0 | ld_p3_in_free1 | ld_p3_in_free2;

   assign cl_p0_in_valid = cl_p0_in_valid1 | cl_p0_in_valid2 | cl_p0_in_valid3;
   assign cl_p1_in_valid = cl_p1_in_valid0 | cl_p1_in_valid2 | cl_p1_in_valid3;
   assign cl_p2_in_valid = cl_p2_in_valid0 | cl_p2_in_valid1 | cl_p2_in_valid3;
   assign cl_p3_in_valid = cl_p3_in_valid0 | cl_p3_in_valid1 | cl_p3_in_valid2;

   // Select logic for port 0
   always_comb begin
      sel_to_p0 = 0; ready_to_p0 = 0;
      if(!ROUTERID) begin
	 if(valids_to_p0[p0_round0] && dests_to_p0[p0_round0] == 4'd0) begin
	    sel_to_p0 = p0_round0; ready_to_p0 = 1;
	 end
	 else if(valids_to_p0[p0_round1] && dests_to_p0[p0_round1] == 4'd0) begin
	    sel_to_p0 = p0_round1; ready_to_p0 = 1;
	 end
	 else if(valids_to_p0[p0_round2] && dests_to_p0[p0_round2] == 4'd0) begin
	    sel_to_p0 = p0_round2; ready_to_p0 = 1;
	 end
      end
      else begin
	 if(valids_to_p0[p0_round0] && dests_to_p0[p0_round0] == 4'd3) begin
	    sel_to_p0 = p0_round0; ready_to_p0 = 1;
	 end
	 else if(valids_to_p0[p0_round1] && dests_to_p0[p0_round1] == 4'd3) begin
	    sel_to_p0 = p0_round1; ready_to_p0 = 1;
	 end
	 else if(valids_to_p0[p0_round2] && dests_to_p0[p0_round2] == 4'd3) begin
	    sel_to_p0 = p0_round2; ready_to_p0 = 1;
	 end
      end
   end // always_comb begin

   fsm_route_transfer route_to_p0 (.ready_to_port(ready_to_p0), .port_full(p0_out_full),
				   .sel_to_port(sel_to_p0),
				   .ld_port(ld_p0_out), .ld_port_full(ld_p0_out_full), .inc_round(inc_p0_round0),
				   .ld_source1_free(ld_p1_in_free0), .cl_source1_valid(cl_p1_in_valid0),
				   .ld_source2_free(ld_p2_in_free0), .cl_source2_valid(cl_p2_in_valid0),
				   .ld_source3_free(ld_p3_in_free0), .cl_source3_valid(cl_p3_in_valid0));
   
   // Select logic for port 1
   always_comb begin
      sel_to_p1 = 0; ready_to_p1 = 0;
      if(!ROUTERID) begin
	 if(valids_to_p1[p1_round0] && dests_to_p1[p1_round0] != 4'd0 &&
	    dests_to_p1[p1_round0] != 4'd1 && dests_to_p1[p1_round0] != 4'd2) begin
	    sel_to_p1 = p1_round0; ready_to_p1 = 1;
	 end
	 else if(valids_to_p1[p1_round1] && dests_to_p1[p1_round1] != 4'd0 &&
		 dests_to_p1[p1_round1] != 4'd1 && dests_to_p1[p1_round1] != 4'd2) begin
	    sel_to_p1 = p1_round1; ready_to_p1 = 1;
	 end
	 else if(valids_to_p1[p1_round2] && dests_to_p1[p1_round2] != 4'd0 &&
		 dests_to_p1[p1_round2] != 4'd1 && dests_to_p1[p1_round2] != 4'd2) begin
	    sel_to_p1 = p1_round2; ready_to_p1 = 1;
	 end
      end
      else begin
	 if(valids_to_p1[p1_round0] && dests_to_p1[p1_round0] == 4'd4) begin
	    sel_to_p1 = p1_round0; ready_to_p1 = 1;
	 end
	 else if(valids_to_p1[p1_round1] && dests_to_p1[p1_round1] == 4'd4) begin
	    sel_to_p1 = p1_round1; ready_to_p1 = 1;
	 end
	 else if(valids_to_p1[p1_round2] && dests_to_p1[p1_round2] == 4'd4) begin
	    sel_to_p1 = p1_round2; ready_to_p1 = 1;
	 end
      end
   end // always_comb begin

   fsm_route_transfer route_to_p1 (.ready_to_port(ready_to_p1), .port_full(p1_out_full),
				   .sel_to_port(sel_to_p1),
				   .ld_port(ld_p1_out), .ld_port_full(ld_p1_out_full), .inc_round(inc_p1_round0),
				   .ld_source1_free(ld_p2_in_free1), .cl_source1_valid(cl_p2_in_valid1),
				   .ld_source2_free(ld_p3_in_free1), .cl_source2_valid(cl_p3_in_valid1),
				   .ld_source3_free(ld_p0_in_free1), .cl_source3_valid(cl_p0_in_valid1));

   // Select logic for port 2
   always_comb begin
      sel_to_p2 = 0; ready_to_p2 = 0;
      if(!ROUTERID) begin
	 if(valids_to_p2[p2_round0] && dests_to_p2[p2_round0] == 4'd1) begin
	    sel_to_p2 = p2_round0; ready_to_p2 = 1;
	 end
	 else if(valids_to_p2[p2_round1] && dests_to_p2[p2_round1] == 4'd1) begin
	    sel_to_p2 = p2_round1; ready_to_p2 = 1;
	 end
	 else if(valids_to_p2[p2_round2] && dests_to_p2[p2_round2] == 4'd1) begin
	    sel_to_p2 = p2_round2; ready_to_p2 = 1;
	 end
      end
      else begin
	 if(valids_to_p2[p2_round0] && dests_to_p2[p2_round0] == 4'd5) begin
	    sel_to_p2 = p2_round0; ready_to_p2 = 1;
	 end
	 else if(valids_to_p2[p2_round1] && dests_to_p2[p2_round1] == 4'd5) begin
	    sel_to_p2 = p2_round1; ready_to_p2 = 1;
	 end
	 else if(valids_to_p2[p2_round2] && dests_to_p2[p2_round2] == 4'd5) begin
	    sel_to_p2 = p2_round2; ready_to_p2 = 1;
	 end
      end
   end // always_comb begin

   
   fsm_route_transfer route_to_p2 (.ready_to_port(ready_to_p2), .port_full(p2_out_full),
				   .sel_to_port(sel_to_p2),
				   .ld_port(ld_p2_out), .ld_port_full(ld_p2_out_full), .inc_round(inc_p2_round0),
				   .ld_source1_free(ld_p3_in_free2), .cl_source1_valid(cl_p3_in_valid2),
				   .ld_source2_free(ld_p0_in_free2), .cl_source2_valid(cl_p0_in_valid2),
				   .ld_source3_free(ld_p1_in_free2), .cl_source3_valid(cl_p1_in_valid2));
   
   // Select logic for port 3
   always_comb begin
      sel_to_p3 = 0; ready_to_p3 = 0;
      if(!ROUTERID) begin
	 if(valids_to_p3[p3_round0] && dests_to_p3[p3_round0] == 4'd2) begin
	    sel_to_p3 = p3_round0; ready_to_p3 = 1;
	 end
	 else if(valids_to_p3[p3_round1] && dests_to_p3[p3_round1] == 4'd2) begin
	    sel_to_p3 = p3_round1; ready_to_p3 = 1;
	 end
	 else if(valids_to_p3[p3_round2] && dests_to_p3[p3_round2] == 4'd2) begin
	    sel_to_p3 = p3_round2; ready_to_p3 = 1;
	 end
      end
      else begin
	 if(valids_to_p3[p3_round0] && dests_to_p3[p3_round0] != 4'd3 &&
	    dests_to_p3[p3_round0] != 4'd4 && dests_to_p3[p3_round0] != 4'd5) begin
	    sel_to_p3 = p3_round0; ready_to_p3 = 1;
	 end
	 else if(valids_to_p3[p3_round1] && dests_to_p3[p3_round1] != 4'd3 &&
		 dests_to_p3[p3_round1] != 4'd4 && dests_to_p3[p3_round1] != 4'd5) begin
	    sel_to_p3 = p3_round1; ready_to_p3 = 1;
	 end
	 else if(valids_to_p3[p3_round2] && dests_to_p3[p3_round2] != 4'd3 &&
		 dests_to_p3[p3_round2] != 4'd4 && dests_to_p3[p3_round2] != 4'd5) begin
	    sel_to_p3 = p3_round2; ready_to_p3 = 1;
	 end
      end
   end // always_comb begin

   fsm_route_transfer route_to_p3 (.ready_to_port(ready_to_p3), .port_full(p3_out_full),
				   .sel_to_port(sel_to_p3),
				   .ld_port(ld_p3_out), .ld_port_full(ld_p3_out_full), .inc_round(inc_p3_round0),
				   .ld_source1_free(ld_p0_in_free3), .cl_source1_valid(cl_p0_in_valid3),
				   .ld_source2_free(ld_p1_in_free3), .cl_source2_valid(cl_p1_in_valid3),
				   .ld_source3_free(ld_p2_in_free3), .cl_source3_valid(cl_p2_in_valid3));

endmodule // router


module fsm_route_transfer
  (input logic ready_to_port, port_full,
   input logic [1:0] sel_to_port,
   output logic ld_port, ld_port_full, inc_round,
   output logic ld_source1_free, cl_source1_valid,
   output logic ld_source2_free, cl_source2_valid,
   output logic ld_source3_free, cl_source3_valid);

   always_comb begin
      ld_port = 0; ld_port_full = 0; inc_round = 0;
      ld_source1_free = 0; cl_source1_valid = 0;
      ld_source2_free = 0; cl_source2_valid = 0;
      ld_source3_free = 0; cl_source3_valid = 0;
      if(ready_to_port && !port_full) begin
	 ld_port = 1; ld_port_full = 1; inc_round = 1;
	 if(sel_to_port == 2'd0) begin
	    ld_source1_free = 1; cl_source1_valid = 1;
	 end
	 else if(sel_to_port == 2'd1) begin
	    ld_source2_free = 1; cl_source2_valid = 1;
	 end
	 else if(sel_to_port == 2'd2) begin
	    ld_source3_free = 1; cl_source3_valid = 1;
	 end
      end // if (ready_to_port && !port_full)
   end // always_comb begin

endmodule: fsm_route_transfer


module fsm_write_out
  (input logic clk, rst_b,
   input logic full, free_out,
   output logic put_out, cl_full,
   output logic [1:0] count);

   enum 	      logic {s1 = 1'b0, s2 = 1'b1} CS, NS;
   logic 	      cl_count, inc_count;

   counter #(2) select (.clk(clk), .rst_b(rst_b), .cl(cl_count), .inc(inc_count),
			.dec(1'b0), .Q(count));

   always_ff @(posedge clk, negedge rst_b) begin
      if(~rst_b)
	CS <= s1;
      else
	CS <= NS;
   end

   always_comb begin
      put_out = 0; cl_full = 0; cl_count = 0; inc_count = 0;
      case(CS)
	s1: begin
	   if(!(full && free_out)) begin
	      NS = s1;
	   end
	   else begin
	      put_out = 1; inc_count = 1;
	      NS = s2;
	   end
	end

	s2: begin
	   if(count != 2'd3) begin
	      put_out = 1; inc_count = 1;
	      NS = s2;
	   end
	   else begin
	      put_out = 1; cl_count = 1; cl_full = 1;
	      NS = s1;
	   end
	end
      endcase // case (CS)
   end
   

endmodule: fsm_write_out

module fsm_load_in
  (input logic clk, rst_b,
   input logic put,
   output logic ld, cl_free, ld_valid,
   output logic [1:0] count);

   enum 	      logic {s1 = 1'b0, s2 = 1'b1} CS, NS;
   logic 	      cl_count, inc_count;
   
   counter #(2) select (.clk(clk), .rst_b(rst_b), .cl(cl_count), .inc(inc_count),
			.dec(1'b0), .Q(count));

   always_ff @(posedge clk, negedge rst_b) begin
      if(~rst_b)
	CS <= s1;
      else
	CS <= NS;
   end

   always_comb begin
      ld = 0; cl_free = 0; ld_valid = 0; cl_count = 0; inc_count = 0;
      case(CS)
	s1: begin
	   if(!put) begin
	      NS = s1;
	   end
	   else begin
	      ld = 1; inc_count = 1; cl_free = 1;
	      NS = s2;
	   end
	end

	s2: begin
	   if(count != 2'd3) begin
	      ld = 1; inc_count = 1;
	      NS = s2;
	   end
	   else begin
	      ld = 1; cl_count = 1; ld_valid = 1;
	      NS = s1;
	   end
	end	
      endcase // case (CS)
   end
   

endmodule: fsm_load_in

module mux3to1
  (input logic [31:0] A, B, C,
   input logic [1:0] sel,
   output logic [31:0] out);

   always_comb begin
      if(sel == 2'b00)
	out = A;
      else if (sel == 2'b01)
	out = B;
      else
	out = C;
   end

endmodule: mux3to1

module countto2
  (input logic clk, rst_b, cl, inc,
   output logic [1:0] Q);

   always_ff @(posedge clk, negedge rst_b) begin
      if(~rst_b)
	Q <= 2'b0;
      else if(cl)
	Q <= 2'b0;
      else if(inc && Q == 2'd2)
	Q <= 2'b0;
      else if(inc)
	Q <= Q + 1;
   end

endmodule: countto2
