// Write your usb host here.  Do not modify the port list.
module usbHost
  (input logic clk, rst_L, 
   usbWires wires);
   
   /* Tasks needed to be finished to run testbenches */

   logic prelab_start, prelab_done;
   sendOutPacket prelab(.clk(clk), .rst_L(rst_L),
   			.addr(7'd5), .endp(4'd4),
   			.start(prelab_start), .all_done(prelab_done),
   			.DP(wires.DP), .DM(wires.DM));

   task prelabRequest
     // sends an OUT packet with ADDR=5 and ENDP=4
     // packet should have SYNC and EOP too
     (input bit  [7:0] data);

      prelab_start <= 1;
      wait(prelab_done);
      prelab_start <= 0;
      
   endtask: prelabRequest

   logic read_start, read_done, read_failed;
   logic [15:0] read_mem;
   logic [63:0] read_data;

   doRead readIt(.clk(clk), .rst_L(rst_L), .start(read_start), .mempage(read_mem),
		 .done(read_done), .failed(read_failed), .data(read_data),
		 .DP(wires.DP), .DM(wires.DM));

   task readData
     // host sends memPage to thumb drive and then gets data back from it
     // then returns data and status to the caller
     (input  bit [15:0]  mempage, // Page to write
      output bit [63:0] data, // array of bytes to write
      output bit        success);

      read_mem <= mempage;
      read_start <= 1;
      wait(read_done);
      read_start <= 0;
      data <= read_data;
      success <= ~read_failed;
      @(posedge clk);

   endtask: readData
   

   logic 		write_start, write_done, write_failed;
   logic [15:0] 	write_mem;
   logic [63:0] 	write_data;

   doWrite writeIt(.clk(clk), .rst_L(rst_L), .start(write_start),
		   .mempage(write_mem), .data(write_data),
		   .done(write_done), .failed(write_failed),
		   .DP(wires.DP), .DM(wires.DM));

   task writeData
     // Host sends memPage to thumb drive and then sends data
     // then returns status to the caller
     (input  bit [15:0]  mempage, // Page to write
      input  bit [63:0] data, // array of bytes to write
      output bit        success);

      write_mem <= mempage;
      write_data <= data;
      write_start <= 1;
      wait(write_done);
      write_start <= 0;
      success <= ~write_failed;
      @(posedge clk);

   endtask: writeData

endmodule: usbHost

/*
 * Do a read transaction at the specified mempage.
 * 
 */
module doRead
  (input logic clk, rst_L,
   input logic start,
   input logic [15:0] mempage,
   output logic done, failed,
   output logic [63:0] data,
   inout tri0 DP, DM);

   logic      doOut_start, doOut_done, doOut_failed;
   logic      doIn_start, doIn_done, doIn_failed;

   doOutTransaction doOut
     (.clk(clk), .rst_L(rst_L), .addr(7'd5), .endp(4'd4), .data({mempage, 48'b0}),
      .start(doOut_start), .all_done(doOut_done), .failed(doOut_failed),
      .DP(DP), .DM(DM));

   doInTransaction doIn
     (.clk(clk), .rst_L(rst_L), .addr(7'd5), .endp(4'd8),
      .start(doIn_start), .all_done(doIn_done), .failed(doIn_failed), .data(data),
      .DP(DP), .DM(DM));

   enum       logic [1:0] {A = 2'd0, B = 2'd1, C = 2'd2} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= A;
      else
	CS <= NS;
   end

   always_comb begin
      done = 0; failed = 0;
      doOut_start = 0; doIn_start = 0;
      case(CS)
	A: begin
	   if(start) begin
	      doOut_start = 1;
	      NS = B;
	   end
	   else begin
	      NS = A;
	   end
	end

	B: begin
	   if(~doOut_done) begin
	      NS = B;
	   end
	   else if(doOut_done & ~doOut_failed) begin
	      doIn_start = 1;
	      NS = C;
	   end
	   else if(doOut_done & doOut_failed) begin
	      done = 1; failed = 1;
	      NS = A;
	   end
	   else begin
	      NS = B;
	   end
	end

	C: begin
	   if(~doIn_done) begin
	      NS = C;
	   end
	   else if(doIn_done & ~doIn_failed) begin
	      done = 1;
	      NS = A;
	   end
	   else if(doIn_done & doIn_failed) begin
	      done = 1; failed = 1;
	      NS = A;
	   end
	   else begin
	      NS = C;
	   end
	end
	
      endcase // case (CS)
   end
   
     

endmodule: doRead

/*
 * Do a write transaction at the specified mempage with the given data.
 * 
 */
module doWrite
  (input logic clk, rst_L,
   input logic start,
   input logic [15:0] mempage,
   input logic [63:0] data,
   output logic done, failed,
   inout tri0 DP, DM);

   logic      doOut1_start, doOut1_done, doOut1_failed;
   logic      doOut2_start, doOut2_done, doOut2_failed;

   doOutTransaction doOut1
     (.clk(clk), .rst_L(rst_L), .addr(7'd5), .endp(4'd4), .data({mempage, 48'b0}),
      .start(doOut1_start), .all_done(doOut1_done), .failed(doOut1_failed),
      .DP(DP), .DM(DM));

   doOutTransaction doOut2
     (.clk(clk), .rst_L(rst_L), .addr(7'd5), .endp(4'd8), .data(data),
      .start(doOut2_start), .all_done(doOut2_done), .failed(doOut2_failed),
      .DP(DP), .DM(DM));

   enum       logic [1:0] {A = 2'd0, B = 2'd1, C = 2'd2} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= A;
      else
	CS <= NS;
   end

   always_comb begin
      done = 0; failed = 0;
      doOut1_start = 0; doOut2_start = 0;
      case(CS)
	A: begin
	   if(start) begin
	      doOut1_start = 1;
	      NS = B;
	   end
	   else begin
	      NS = A;
	   end
	end

	B: begin
	   if(~doOut1_done) begin
	      NS = B;
	   end
	   else if(doOut1_done & ~doOut1_failed) begin
	      doOut2_start = 1;
	      NS = C;
	   end
	   else if(doOut1_done & doOut1_failed) begin
	      done = 1; failed = 1;
	      NS = A;
	   end
	   else begin
	      NS = B;
	   end
	end

	C: begin
	   if(~doOut2_done) begin
	      NS = C;
	   end
	   else if(doOut2_done & ~doOut2_failed) begin
	      done = 1;
	      NS = A;
	   end
	   else if(doOut2_done & doOut2_failed) begin
	      done = 1; failed = 1;
	      NS = A;
	   end
	   else begin
	      NS = C;
	   end
	end
	
      endcase // case (CS)
   end
   

endmodule: doWrite

/*
 * Do an IN transaction with the specified address and endpoint, and returns the data.
 * 
 */
module doInTransaction
  (input logic clk, rst_L,
   input logic [6:0] addr,
   input logic [3:0] endp,
   input logic start,
   output logic all_done, failed,
   output logic [63:0] data,
   inout tri0 DP, DM);

   logic      sendIn_start, sendIn_done;
   
   logic      receiveData_start, receiveData_done, error;
   
   logic [63:0] data_in;
   logic 	ld_data;

   logic 	sendACK_start, sendACK_done;
   logic 	sendNAK_start, sendNAK_done;

   logic 	cl_ct, inc_ct;
   logic [3:0] 	count;

   sendInPacket sendIn
     (.clk(clk), .rst_L(rst_L), .addr(addr), .endp(endp),
      .start(sendIn_start), .all_done(sendIn_done), .DP(DP), .DM(DM));

   receiveDataPacket receiveData
     (.clk(clk), .rst_L(rst_L), .start(receiveData_start), .DP(DP), .DM(DM),
      .all_done(receiveData_done), .error(error), .data(data_in));

   register #(64) data_catch
     (.clk(clk), .rst_L(rst_L), .ld(ld_data), .cl(1'b0), .D(data_in), .Q(data));

   sendACKPacket sendACK
     (.clk(clk), .rst_L(rst_L), .start(sendACK_start), .all_done(sendACK_done),
      .DP(DP), .DM(DM));

   sendNAKPacket sendNAK
     (.clk(clk), .rst_L(rst_L), .start(sendNAK_start), .all_done(sendNAK_done),
      .DP(DP), .DM(DM));

   counter #(4) fail_count
     (.clk(clk), .rst_L(rst_L), .ld(1'b0), .cl(cl_ct), .inc(inc_ct), .dec(1'b0),
      .D(4'b0), .Q(count));

   enum 	logic [2:0] {A = 3'd0, B = 3'd1, C = 3'd2, D = 3'd3, E = 3'd4} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= A;
      else
	CS <= NS;
   end

   always_comb begin
      all_done = 0; failed = 0;
      sendIn_start = 0; receiveData_start = 0; sendACK_start = 0; sendNAK_start = 0;
      cl_ct = 0; inc_ct = 0; ld_data = 0;
      case(CS)
	A: begin
	   if(start) begin
	      sendIn_start = 1;
	      NS = B;
	   end
	   else begin
	      NS = A;
	   end
	end

	B: begin
	   if(sendIn_done) begin
	      receiveData_start = 1; inc_ct = 1;
	      NS = C;
	   end
	   else begin
	      NS = B;
	   end
	end

	C: begin
	   if(~receiveData_done) begin
	      NS = C;
	   end
	   else if(receiveData_done & ~error) begin
      	      sendACK_start = 1; ld_data = 1;
	      NS = E;
	   end
	   else if(receiveData_done & error) begin
	      sendNAK_start = 1;
	      NS = D;
	   end
	   else begin
	      NS = C;
	   end
	end

	D: begin
	   if(~sendNAK_done) begin
	      NS = D;
	   end
	   else if(sendNAK_done & (count != 4'd8)) begin
	      receiveData_start = 1; inc_ct = 1;
	      NS = C;
	   end
	   else if(sendNAK_done & (count == 4'd8)) begin
	      cl_ct = 1; all_done = 1; failed = 1;
	      NS = A;
	   end
	   else begin
	      NS = D;
	   end
	end

	E: begin
	   if(~sendACK_done) begin
	      NS = E;
	   end
	   else begin
	      cl_ct = 1; all_done = 1;
	      NS = A;
	   end
	end	
      endcase // case (CS)
   end // always_comb begin   

endmodule: doInTransaction

/*
 * Do an OUT transaction with the specified address, endpoint, and data.
 * 
 */
module doOutTransaction
  (input logic clk, rst_L,
   input logic [6:0] addr,
   input logic [3:0] endp,
   input logic [63:0] data,
   input logic start,
   output logic all_done, failed,
   inout tri0 DP, DM);

   logic      sendOut_start, sendOut_done;
   logic      sendData_start, sendData_done;
   logic      receiveHandshake_start, receiveHandshake_done, error, ack;
   logic      cl_ct, inc_ct;
   logic [3:0] count;

   sendOutPacket sendOut
     (.clk(clk), .rst_L(rst_L), .addr(addr), .endp(endp),
      .start(sendOut_start), .all_done(sendOut_done), .DP(DP), .DM(DM));

   sendDataPacket sendData
     (.clk(clk), .rst_L(rst_L), .data(data),
      .start(sendData_start), .all_done(sendData_done), .DP(DP), .DM(DM));

   receiveHandshakePacket receiveHandshake
     (.clk(clk), .rst_L(rst_L), .start(receiveHandshake_start),
      .all_done(receiveHandshake_done), .error(error), .ack(ack), .DP(DP), .DM(DM));

   counter #(4) fail_count
     (.clk(clk), .rst_L(rst_L), .ld(1'b0), .cl(cl_ct), .inc(inc_ct), .dec(1'b0),
      .D(4'b0), .Q(count));

   enum        logic [1:0] {A = 2'd0, B = 2'd1, C = 2'd2, D = 2'd3} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= A;
      else
	CS <= NS;
   end

   always_comb begin
      all_done = 0; failed = 0;
      sendOut_start = 0; sendData_start = 0; receiveHandshake_start = 0;
      cl_ct = 0; inc_ct = 0;
      case(CS)
	A: begin
	   if(start) begin
	      sendOut_start = 1;
	      NS = B;
	   end
	   else begin
	      NS = A;
	   end
	end

	B: begin
	   if(sendOut_done) begin
	      sendData_start = 1; inc_ct = 1;
	      NS = C;
	   end
	   else begin
	      NS = B;
	   end
	end

	C: begin
	   if(~sendData_done) begin
	      NS = C;
	   end
	   else begin
	      receiveHandshake_start = 1;
	      NS = D;
	   end
	end

	D: begin
	   if(~receiveHandshake_done) begin
	      NS = D;
	   end
	   else if(receiveHandshake_done & (error | ~ack) & (count != 4'd8)) begin
	      sendData_start = 1; inc_ct = 1;
	      NS = C;
	   end
	   else if(receiveHandshake_done & (error | ~ack) & (count == 4'd8)) begin
	      cl_ct = 1; all_done = 1; failed = 1;
	      NS = A;
	   end
	   else if(receiveHandshake_done & ~error & ack) begin
	      cl_ct = 1; all_done = 1;
	      NS = A;
	   end
	   else begin
	      NS = D;
	   end
	end
	
      endcase // case (CS)
   end
   

endmodule: doOutTransaction

/*
 * Sends an OUT packet with the specified address and endpoint.
 * 
 */
module sendOutPacket
  (input logic clk, rst_L,
   input logic [6:0] addr,
   input logic [3:0] endp,
   input logic start,
   output logic all_done,
   inout tri0 DP, DM);

   logic      bitstuff_start, bitstuff_stop, bitstuffing;   
   logic      encoder_out, encoder_out_valid;
   logic      stuffer_out, stuffer_out_valid;
   logic      J, K, SE0;

   bitStreamEncoder_Token encoder
     (.clk(clk), .rst_L(rst_L), .start(start), .PID(4'b0001), .ADDR(addr), .ENDP(endp),
      .stuffing(bitstuffing), .bitstuff_start(bitstuff_start), .bitstuff_stop(bitstuff_stop),
      .bit_out(encoder_out), .bit_out_valid(encoder_out_valid),
      .all_done(all_done));

   bitStuff stuffer
     (.clk(clk), .rst_L(rst_L), .stuff_start(bitstuff_start), .stuff_stop(bitstuff_stop),
      .bit_in(encoder_out), .bit_in_valid(encoder_out_valid),
      .bit_out(stuffer_out), .bit_out_valid(stuffer_out_valid),
      .stuffing(bitstuffing));

   nrzi nrzier
     (.clk(clk), .rst_L(rst_L), .bit_in(stuffer_out), .bit_in_valid(stuffer_out_valid),
      .J(J), .K(K), .SE0(SE0));

   dpdm dpdmer
     (.J(J), .K(K), .SE0(SE0), .DP(DP), .DM(DM));

endmodule: sendOutPacket

/*
 * Sends an IN packet with the specified address and endpoint.
 * 
 */
module sendInPacket
  (input logic clk, rst_L,
   input logic [6:0] addr,
   input logic [3:0] endp,
   input logic start,
   output logic all_done,
   inout tri0 DP, DM);

   logic      bitstuff_start, bitstuff_stop, bitstuffing;   
   logic      encoder_out, encoder_out_valid;
   logic      stuffer_out, stuffer_out_valid;
   logic      J, K, SE0;

   bitStreamEncoder_Token encoder
     (.clk(clk), .rst_L(rst_L), .start(start), .PID(4'b1001), .ADDR(addr), .ENDP(endp),
      .stuffing(bitstuffing), .bitstuff_start(bitstuff_start), .bitstuff_stop(bitstuff_stop),
      .bit_out(encoder_out), .bit_out_valid(encoder_out_valid),
      .all_done(all_done));

   bitStuff stuffer
     (.clk(clk), .rst_L(rst_L), .stuff_start(bitstuff_start), .stuff_stop(bitstuff_stop),
      .bit_in(encoder_out), .bit_in_valid(encoder_out_valid),
      .bit_out(stuffer_out), .bit_out_valid(stuffer_out_valid),
      .stuffing(bitstuffing));

   nrzi nrzier
     (.clk(clk), .rst_L(rst_L), .bit_in(stuffer_out), .bit_in_valid(stuffer_out_valid),
      .J(J), .K(K), .SE0(SE0));

   dpdm dpdmer
     (.J(J), .K(K), .SE0(SE0), .DP(DP), .DM(DM));

endmodule: sendInPacket

/*
 * Sends a DATA packet with the given data.
 * 
 */
module sendDataPacket
  (input logic clk, rst_L,
   input logic [63:0] data,
   input logic start,
   output logic all_done,
   inout tri0 DP, DM);

   logic      bitstuff_start, bitstuff_stop, bitstuffing;   
   logic      encoder_out, encoder_out_valid;
   logic      stuffer_out, stuffer_out_valid;
   logic      J, K, SE0;

   bitStreamEncoder_Data encoder
     (.clk(clk), .rst_L(rst_L), .start(start), .data(data),
      .stuffing(bitstuffing), .bitstuff_start(bitstuff_start), .bitstuff_stop(bitstuff_stop),
      .bit_out(encoder_out), .bit_out_valid(encoder_out_valid),
      .all_done(all_done));

   bitStuff stuffer
     (.clk(clk), .rst_L(rst_L), .stuff_start(bitstuff_start), .stuff_stop(bitstuff_stop),
      .bit_in(encoder_out), .bit_in_valid(encoder_out_valid),
      .bit_out(stuffer_out), .bit_out_valid(stuffer_out_valid),
      .stuffing(bitstuffing));

   nrzi nrzier
     (.clk(clk), .rst_L(rst_L), .bit_in(stuffer_out), .bit_in_valid(stuffer_out_valid),
      .J(J), .K(K), .SE0(SE0));

   dpdm dpdmer
     (.J(J), .K(K), .SE0(SE0), .DP(DP), .DM(DM));

endmodule: sendDataPacket

/*
 * Sends an ACK packet.
 * 
 */
module sendACKPacket
  (input logic clk, rst_L,
   input logic start,
   output logic all_done,
   inout tri0 DP, DM);

   logic 	send_sync_start, send_sync_done;
   logic 	send_sync_out, send_sync_out_valid;

   assign send_sync_start = start;
   
   sendSerial_MSBtoLSB #(8) send_sync
     (.clk(clk), .rst_L(rst_L), .in(8'b0000_0001),
      .start(send_sync_start), .pause(1'b0),
      .bit_out(send_sync_out), .bit_out_valid(send_sync_out_valid),
      .done(send_sync_done));

   logic 	send_pid_done;
   logic 	send_pid_out, send_pid_out_valid;

   sendSerial_LSBtoMSB #(8) send_pid
     (.clk(clk), .rst_L(rst_L), .in({4'b1101, 4'b0010}),
      .start(send_sync_done), .pause(1'b0),
      .bit_out(send_pid_out), .bit_out_valid(send_pid_out_valid),
      .done(send_pid_done));

   logic 	send_eop_done;
   logic 	send_eop_out, send_eop_out_valid;

   sendSerial_MSBtoLSB #(3) send_eop
     (.clk(clk), .rst_L(rst_L), .in(3'bxx1),
      .start(send_pid_done), .pause(1'b0),
      .bit_out(send_eop_out), .bit_out_valid(send_eop_out_valid),
      .done(send_eop_done));

   logic 	bit_out_valid, bit_out;
   logic 	J, K, SE0;

   
   assign bit_out_valid = send_sync_out_valid | send_pid_out_valid | send_eop_out_valid;
   assign bit_out = (send_sync_out & send_sync_out_valid) | 
		    (send_pid_out & send_pid_out_valid) |
		    (send_eop_out & send_eop_out_valid);
   assign all_done = send_eop_done;

   nrzi nrzier
     (.clk(clk), .rst_L(rst_L), .bit_in(bit_out), .bit_in_valid(bit_out_valid),
      .J(J), .K(K), .SE0(SE0));

   dpdm dpdmer
     (.J(J), .K(K), .SE0(SE0), .DP(DP), .DM(DM));

endmodule: sendACKPacket

/*
 * Sends a NAK packet.
 * 
 */
module sendNAKPacket
  (input logic clk, rst_L,
   input logic start,
   output logic all_done,
   inout tri0 DP, DM);

   logic 	send_sync_start, send_sync_done;
   logic 	send_sync_out, send_sync_out_valid;

   assign send_sync_start = start;
   
   sendSerial_MSBtoLSB #(8) send_sync
     (.clk(clk), .rst_L(rst_L), .in(8'b0000_0001),
      .start(send_sync_start), .pause(1'b0),
      .bit_out(send_sync_out), .bit_out_valid(send_sync_out_valid),
      .done(send_sync_done));

   logic 	send_pid_done;
   logic 	send_pid_out, send_pid_out_valid;

   sendSerial_LSBtoMSB #(8) send_pid
     (.clk(clk), .rst_L(rst_L), .in({4'b0101, 4'b1010}),
      .start(send_sync_done), .pause(1'b0),
      .bit_out(send_pid_out), .bit_out_valid(send_pid_out_valid),
      .done(send_pid_done));

   logic 	send_eop_done;
   logic 	send_eop_out, send_eop_out_valid;

   sendSerial_MSBtoLSB #(3) send_eop
     (.clk(clk), .rst_L(rst_L), .in(3'bxx1),
      .start(send_pid_done), .pause(1'b0),
      .bit_out(send_eop_out), .bit_out_valid(send_eop_out_valid),
      .done(send_eop_done));

   logic 	bit_out_valid, bit_out;
   logic 	J, K, SE0;

   
   assign bit_out_valid = send_sync_out_valid | send_pid_out_valid | send_eop_out_valid;
   assign bit_out = (send_sync_out & send_sync_out_valid) | 
		    (send_pid_out & send_pid_out_valid) |
		    (send_eop_out & send_eop_out_valid);
   assign all_done = send_eop_done;

   nrzi nrzier
     (.clk(clk), .rst_L(rst_L), .bit_in(bit_out), .bit_in_valid(bit_out_valid),
      .J(J), .K(K), .SE0(SE0));

   dpdm dpdmer
     (.J(J), .K(K), .SE0(SE0), .DP(DP), .DM(DM));

endmodule: sendNAKPacket

/*
 * Waits for a DATA packet on the lines and returns it.
 * 
 */
module receiveDataPacket
  (input logic clk, rst_L,
   input logic start,
   inout tri0 DP, DM,
   output logic all_done, error,
   output logic [63:0] data);

   logic 	J, K, SE0;
   logic 	unnrzi_out;

   logic 	unstuffer_out, unstuffing;
   
   logic 	sync_done, timeout;

   logic 	pid_done;
   logic [7:0] 	pid;

   logic 	data_done;

   logic 	crc_done;
   logic [15:0] residue;

   logic 	eop_done;
   logic [2:0] 	eop;

   logic 	idle_done;

   logic 	pid_err, eop_err;   

   undpdm undpdmer
     (.DP(DP), .DM(DM), .J(J), .K(K), .SE0(SE0));

   unnrzi unnrzier
     (.clk(clk), .rst_L(rst_L), .J(J), .K(K), .SE0(SE0), .bit_out(unnrzi_out));

   unStuff unstuffer
     (.clk(clk), .rst_L(rst_L), .start(pid_done), .stop(crc_done), .bit_in(unnrzi_out),
      .bit_out(unstuffer_out), .bit_out_valid(unstuffing));

   wait_sync syncer
     (.clk(clk), .rst_L(rst_L), .bit_in(unstuffer_out),
      .start(start), .done(sync_done), .timeout(timeout));

   receiveSerial #(8) getpid
     (.clk(clk), .rst_L(rst_L), .bit_in(unstuffer_out), .bit_in_valid(unstuffing),
      .start(sync_done), .clr_store(all_done), .done(pid_done), .out(pid));

   receiveSerial #(64) getdata
     (.clk(clk), .rst_L(rst_L), .bit_in(unstuffer_out), .bit_in_valid(unstuffing),
      .start(pid_done), .clr_store(all_done), .done(data_done), .out(data));

   receive_crc16 verifycrc
     (.clk(clk), .rst_L(rst_L), .bit_in(unstuffer_out), .bit_in_valid(unstuffing),
      .start(pid_done), .clr_crc(all_done), .done(crc_done), .crc16(residue));
   
   receiveSerial #(3) geteop
     (.clk(clk), .rst_L(rst_L), .bit_in(unstuffer_out), .bit_in_valid(unstuffing),
      .start(crc_done), .clr_store(all_done), .done(eop_done), .out(eop));

   wait_idle waiter
     (.clk(clk), .rst_L(rst_L), .bit_in(unstuffer_out),
      .start(eop_done), .done(idle_done));
   
   assign pid_err = (pid[7:4] != ~pid[3:0]) | (pid[3:0] != 4'b0011);
   assign eop_err = ~(eop[2] & $isunknown(eop[1]) & $isunknown(eop[0]));

   assign all_done = idle_done | timeout;
   assign error = timeout | pid_err | (residue != 16'h800D) | eop_err;   

endmodule: receiveDataPacket

/*
 * Waits for a handshake packet on the lines and
 * returns whether it is an ACK or NAK.
 * 
 */
module receiveHandshakePacket
  (input logic clk, rst_L,
   input logic start,
   inout tri0 DP, DM,
   output logic all_done, error, ack);

   logic 	J, K, SE0;
   logic 	unnrzi_out;
   
   logic 	sync_done, timeout;
   
   logic 	pid_done;
   logic [7:0] 	pid;
   
   logic 	eop_done;
   logic [2:0] 	eop;

   logic 	idle_done;

   logic 	pid_err, eop_err;
   
   undpdm undpdmer
     (.DP(DP), .DM(DM), .J(J), .K(K), .SE0(SE0));

   unnrzi unnrzier
     (.clk(clk), .rst_L(rst_L), .J(J), .K(K), .SE0(SE0), .bit_out(unnrzi_out));

   wait_sync syncer
     (.clk(clk), .rst_L(rst_L), .bit_in(unnrzi_out),
      .start(start), .done(sync_done), .timeout(timeout));   

   receiveSerial #(8) getpid
     (.clk(clk), .rst_L(rst_L), .bit_in(unnrzi_out), .bit_in_valid(1'b1),
      .start(sync_done), .clr_store(all_done), .done(pid_done), .out(pid));

   receiveSerial #(3) geteop
     (.clk(clk), .rst_L(rst_L), .bit_in(unnrzi_out), .bit_in_valid(1'b1),
      .start(pid_done), .clr_store(all_done), .done(eop_done), .out(eop));

   wait_idle waiter
     (.clk(clk), .rst_L(rst_L), .bit_in(unstuffer_out),
      .start(eop_done), .done(idle_done));
   
   assign pid_err = (pid[7:4] != ~pid[3:0]) | 
		    ((pid[3:0] != 4'b0010) & (pid[3:0] != 4'b1010));
   assign eop_err = ~(eop[2] & $isunknown(eop[1]) & $isunknown(eop[0]));

   assign all_done = idle_done | timeout;
   assign error = pid_err | eop_err;
   assign ack = (pid[3:0] == 4'b0010);   

endmodule: receiveHandshakePacket

/*
 * Encodes the bits for a DATA packet.
 * 
 */
module bitStreamEncoder_Data
  (input logic clk, rst_L,
   input logic start,
   input logic [63:0] data,
   input logic stuffing,
   output logic bitstuff_start, bitstuff_stop,
   output logic bit_out, bit_out_valid,
   output logic all_done);


   logic 	send_sync_start, send_sync_done;
   logic 	send_sync_out, send_sync_out_valid;

   assign send_sync_start = start;
   
   sendSerial_MSBtoLSB #(8) send_sync
     (.clk(clk), .rst_L(rst_L), .in(8'b0000_0001),
      .start(send_sync_start), .pause(stuffing),
      .bit_out(send_sync_out), .bit_out_valid(send_sync_out_valid),
      .done(send_sync_done));

   logic 	send_pid_done;
   logic 	send_pid_out, send_pid_out_valid;

   sendSerial_LSBtoMSB #(8) send_pid
     (.clk(clk), .rst_L(rst_L), .in({4'b1100, 4'b0011}),
      .start(send_sync_done), .pause(stuffing),
      .bit_out(send_pid_out), .bit_out_valid(send_pid_out_valid),
      .done(send_pid_done));

   assign bitstuff_start = send_pid_done;

   logic 	send_data_done;
   logic 	send_data_out, send_data_out_valid;

   sendSerial_LSBtoMSB #(64) send_data
     (.clk(clk), .rst_L(rst_L), .in(data),
      .start(send_pid_done), .pause(stuffing),
      .bit_out(send_data_out), .bit_out_valid(send_data_out_valid),
      .done(send_data_done));

   logic 	crc_clr;
   logic [15:0] crc_rem;

   crc16_datapath crcD(.clk(clk), .rst_L(rst_L),
		       .bit_in(send_data_out), .shift(send_data_out_valid),
		       .clr(crc_clr), .rem(crc_rem));

   logic 	send_crc_done;
   logic 	send_crc_out, send_crc_out_valid;

   sendSerial_MSBtoLSB #(16) send_crc
     (.clk(clk), .rst_L(rst_L), .in(~crc_rem),
      .start(send_data_done), .pause(stuffing),
      .bit_out(send_crc_out), .bit_out_valid(send_crc_out_valid),
      .done(send_crc_done));

   
   assign crc_clr = send_crc_done;
   
   assign bitstuff_stop = send_crc_done;

   logic 	send_eop_done;
   logic 	send_eop_out, send_eop_out_valid;

   sendSerial_MSBtoLSB #(3) send_eop
     (.clk(clk), .rst_L(rst_L), .in(3'bxx1),
      .start(send_crc_done), .pause(stuffing),
      .bit_out(send_eop_out), .bit_out_valid(send_eop_out_valid),
      .done(send_eop_done));

   assign all_done = send_eop_done;

   assign bit_out_valid = send_sync_out_valid | send_pid_out_valid |
			  send_data_out_valid | send_crc_out_valid |
			  send_eop_out_valid;
   assign bit_out = (send_sync_out & send_sync_out_valid) | 
		    (send_pid_out & send_pid_out_valid) | 
		    (send_data_out & send_data_out_valid) |
		    (send_crc_out & send_crc_out_valid) |
		    (send_eop_out & send_eop_out_valid);

endmodule: bitStreamEncoder_Data

/*
 * Encodes the bits for a TOKEN packet.
 * 
 */
module bitStreamEncoder_Token
  (input logic clk, rst_L,
   input logic start,
   input logic [3:0] PID,
   input logic [6:0] ADDR,
   input logic [3:0] ENDP,
   input logic stuffing,
   output logic bitstuff_start, bitstuff_stop,
   output logic bit_out, bit_out_valid,
   output logic all_done);

   
   logic 	send_sync_start, send_sync_done;
   logic 	send_sync_out, send_sync_out_valid;
   
   sendSerial_MSBtoLSB #(8) send_sync
     (.clk(clk), .rst_L(rst_L), .in(8'b0000_0001),
      .start(send_sync_start), .pause(stuffing),
      .bit_out(send_sync_out), .bit_out_valid(send_sync_out_valid),
      .done(send_sync_done));

   logic 	send_pid_done;
   logic 	send_pid_out, send_pid_out_valid;

   sendSerial_LSBtoMSB #(8) send_pid
     (.clk(clk), .rst_L(rst_L), .in({~PID, PID}),
      .start(send_sync_done), .pause(stuffing),
      .bit_out(send_pid_out), .bit_out_valid(send_pid_out_valid),
      .done(send_pid_done));

   assign bitstuff_start = send_pid_done;

   logic 	send_addr_done;
   logic 	send_addr_out, send_addr_out_valid;

   sendSerial_LSBtoMSB #(7) send_addr
     (.clk(clk), .rst_L(rst_L), .in(ADDR),
      .start(send_pid_done), .pause(stuffing),
      .bit_out(send_addr_out), .bit_out_valid(send_addr_out_valid),
      .done(send_addr_done));

   logic 	send_endp_done;
   logic 	send_endp_out, send_endp_out_valid;

   sendSerial_LSBtoMSB #(4) send_endp
     (.clk(clk), .rst_L(rst_L), .in(ENDP),
      .start(send_addr_done), .pause(stuffing),
      .bit_out(send_endp_out), .bit_out_valid(send_endp_out_valid),
      .done(send_endp_done));

   logic 	crc_in, crc_shift, crc_clr;
   logic [4:0] 	crc_rem;
   logic 	send_crc_start, send_crc_done;
   logic 	send_crc_out, send_crc_out_valid;

   crc5_datapath crcD(.clk(clk), .rst_L(rst_L), .bit_in(crc_in), .shift(crc_shift), .clr(crc_clr),
		      .rem(crc_rem));

   sendSerial_MSBtoLSB #(5) send_crc
     (.clk(clk), .rst_L(rst_L), .in(~crc_rem),
      .start(send_endp_done), .pause(stuffing),
      .bit_out(send_crc_out), .bit_out_valid(send_crc_out_valid),
      .done(send_crc_done));

   assign crc_shift = send_addr_out_valid | send_endp_out_valid;
   assign crc_in = (send_addr_out_valid & send_addr_out) |
		   (send_endp_out_valid & send_endp_out);
   assign crc_clr = send_crc_done;

   assign bitstuff_stop = send_crc_done;   

   logic 	send_eop_start, send_eop_done;
   logic 	send_eop_out, send_eop_out_valid;

   sendSerial_MSBtoLSB #(3) send_eop
     (.clk(clk), .rst_L(rst_L), .in(3'bxx1),
      .start(send_eop_start), .pause(stuffing),
      .bit_out(send_eop_out), .bit_out_valid(send_eop_out_valid),
      .done(send_eop_done));

   enum  logic [2:0] {sync_out = 3'd0, pid_out = 3'd1, addr_out = 3'd2, endp_out = 3'd3,
		      crc_out = 3'd4, none = 3'd5} which_out;
   
   assign bit_out_valid = send_sync_out_valid | send_pid_out_valid |
			  send_addr_out_valid | send_endp_out_valid |
			  send_crc_out_valid | send_eop_out_valid;
   assign bit_out = (send_sync_out & send_sync_out_valid) | 
		    (send_pid_out & send_pid_out_valid) | 
		    (send_addr_out & send_addr_out_valid) |
		    (send_endp_out & send_endp_out_valid) |
		    (send_crc_out & send_crc_out_valid) |
		    (send_eop_out & send_eop_out_valid);
   
   enum logic [2:0] {s1 = 3'd0, s2 = 3'd1, s3 = 3'd2, s4 = 3'd3,
		     s5 = 3'd4, s6 = 3'd5, s7 = 3'd6, s8 = 3'd7} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= s1;
      else
	CS <= NS;
   end

   always_comb begin
      send_sync_start = 0; send_eop_start = 0;
      all_done = 0;
      case(CS)
	s1: begin
	   if(start) begin
	      send_sync_start = 1;
	      NS = s2;
	   end
	   else begin
	      NS = s1;
	   end
	end

	s2: begin
	   if(send_crc_done) begin
	      send_eop_start = 1;
	      NS = s3;
	   end
	   else begin
	      NS = s2;
	   end
	end

	s3: begin
	   if(send_eop_done) begin
	      all_done = 1;
	      NS = s1;
	   end
	   else begin
	      NS = s3;
	   end
	end

      endcase // case (CS)
   end // always_ff @ (posedge clk, negedge rst_L)

endmodule: bitStreamEncoder_Token

/*
 * Sends the bits of 'in' from MSB to LSB serially.
 * 
 */
module sendSerial_MSBtoLSB
  #(parameter W = 8, C = $clog2(W) + 1)
   (input logic clk, rst_L,
    input logic [W-1:0] in,
    input logic start, pause,
    output logic bit_out, bit_out_valid, done);

   logic [C-1:0] count;
   logic 	 ld_ct, dec_ct;

   counter #(C, W) ctr(.clk(clk), .rst_L(rst_L), .ld(ld_ct), .cl(1'b0),
		       .inc(1'b0), .dec(dec_ct), .D(W), .Q(count));

   assign bit_out = in[count - 1];

   enum 	 logic {s1 = 1'b0, s2 = 1'b1} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= s1;
      else
	CS <= NS;
   end

   always_comb begin
      ld_ct = 0; dec_ct = 0; bit_out_valid = 0; done = 0;
      case(CS)
	s1: begin
	   if(start) begin
	      bit_out_valid = 1; dec_ct = 1;
	      NS = s2;
	   end
	   else begin
	      NS = s1;
	   end
	end

	s2: begin
	   if(pause) begin
	      NS = s2;
	   end
	   else if(count != 0) begin
	      bit_out_valid = 1; dec_ct = 1;
	      NS = s2;
	   end
	   else begin
	      done = 1;
	      ld_ct = 1;
	      NS = s1;
	   end
	end
	
      endcase // case (CS)
   end
   
endmodule: sendSerial_MSBtoLSB

/*
 * Sends the bits of 'in' from LSB to MSB serially.
 * 
 */
module sendSerial_LSBtoMSB
  #(parameter W = 8, C = $clog2(W)+1)
   (input logic clk, rst_L,
    input logic [W-1:0] in,
    input logic start, pause,
    output logic bit_out, bit_out_valid, done);

   logic [C-1:0] count;
   logic 	 cl_ct, inc_ct;

   counter #(C) ctr(.clk(clk), .rst_L(rst_L), .ld(1'b0), .cl(cl_ct),
		    .inc(inc_ct), .dec(1'b0), .D('b0), .Q(count));

   assign bit_out = in[count];

   enum 	 logic {s1 = 1'b0, s2 = 1'b1} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= s1;
      else
	CS <= NS;
   end

   always_comb begin
      cl_ct = 0; inc_ct = 0; bit_out_valid = 0; done = 0;
      case(CS)
	s1: begin
	   if(start) begin
	      bit_out_valid = 1; inc_ct = 1;
	      NS = s2;
	   end
	   else begin
	      NS = s1;
	   end
	end

	s2: begin
	   if(pause) begin
	      NS = s2;
	   end
	   else if(count != W) begin
	      bit_out_valid = 1; inc_ct = 1;
	      NS = s2;
	   end
	   else begin
	      done = 1;
	      cl_ct = 1;
	      NS = s1;
	   end
	end
	
      endcase // case (CS)
   end
   
endmodule: sendSerial_LSBtoMSB

/*
 * Waits for a correct SYNC on the lines.
 * 
 */
module wait_sync
  (input logic clk, rst_L,
   input logic bit_in,
   input logic start,
   output logic done, timeout);

   logic 	cl_idle_ct, inc_idle_ct;
   logic [7:0] 	idle_ct;
   
   counter #(8) idle_counter (.clk(clk), .rst_L(rst_L), .ld(1'b0), .cl(cl_idle_ct),
			      .inc(inc_idle_ct), .dec(1'b0), .D(8'b0), .Q(idle_ct));

   logic 	cl_zero_ct, inc_zero_ct;
   logic [2:0] 	zero_ct;
   
   counter #(3) zero_counter (.clk(clk), .rst_L(rst_L), .ld(1'b0), .cl(cl_zero_ct),
			      .inc(inc_zero_ct), .dec(1'b0), .D(3'b0), .Q(zero_ct));

   enum 	logic [1:0] {A = 2'd0, B = 2'd1, C = 2'd2, D = 2'd3} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= A;
      else
	CS <= NS;
   end

   always_comb begin
      done = 0; timeout = 0;
      cl_idle_ct = 0; inc_idle_ct = 0;
      cl_zero_ct = 0; inc_zero_ct = 0;
      case(CS)
	A: begin
	   if(start & (bit_in | $isunknown(bit_in))) begin
	      inc_idle_ct = 1;
	      NS = B;
	   end
	   else if(start & ~bit_in) begin
	      inc_idle_ct = 1; inc_zero_ct = 1;
	      NS = B;
	   end
	   else begin
	      NS = A;
	   end
	end

	B: begin
	   if(zero_ct == 3'd7 & bit_in) begin
	      cl_idle_ct = 1; cl_zero_ct = 1;
	      NS = C;
	   end
	   else if(idle_ct == 8'd255) begin
	      cl_idle_ct = 1; cl_zero_ct = 1; timeout = 1;
	      NS = A;
	   end
	   else if(zero_ct == 3'd7 & ~bit_in) begin
	      inc_idle_ct = 1;
	      NS = B;
	   end
	   else if(zero_ct == 3'd7 & $isunknown(bit_in)) begin
	      inc_idle_ct = 1; cl_zero_ct = 1;
	      NS = B;
	   end
	   else if(zero_ct != 3'd7 & ~bit_in) begin
	      inc_idle_ct = 1; inc_zero_ct = 1;
	      NS = B;
	   end
	   else if(zero_ct != 3'd7 & (bit_in | $isunknown(bit_in))) begin
	      inc_idle_ct = 1; cl_zero_ct = 1;
	      NS = B;
	   end
	   else begin
	      NS = B;
	   end
	end

	C: begin
	   done = 1;
	   NS = A;
	end
	
      endcase // case (CS)
   end
   
endmodule: wait_sync

/*
 * Receives W bits on the line serially from LSB to MSB.
 * 
 */
module receiveSerial
  #(parameter W = 8, C = $clog2(W))
   (input logic clk, rst_L,
    input logic bit_in, bit_in_valid,
    input logic start, clr_store,
    output logic done,
    output logic [W-1:0] out);

   logic 		 ld_ct, dec_ct;
   logic [C-1:0] 	 count;

   counter #(C, W-1) ctr(.clk(clk), .rst_L(rst_L), .ld(ld_ct), .cl(1'b0),
			 .inc(1'b0), .dec(dec_ct), .D(W-1), .Q(count));

   logic 		 shift;
   
   shift_in #(W) store(.clk(clk), .rst_L(rst_L), .shift(shift), .cl(clr_store),
		       .in(bit_in), .Q(out));

   enum 		 logic {A = 1'd0, B = 1'd1} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= A;
      else
	CS <= NS;
   end

   always_comb begin
      done = 0; shift = 0; ld_ct = 0; dec_ct = 0;
      case(CS)
	A: begin
	   if(start) begin
	      shift = 1; dec_ct = 1;
	      NS = B;
	   end
	   else begin
	      NS = A;
	   end
	end

	B: begin
	   if(count < (W-1) & bit_in_valid) begin
	      shift = 1; dec_ct = 1;
	      NS = B;
	   end
	   else if(count >= (W-1) & bit_in_valid) begin
	      done = 1; ld_ct = 1;
	      NS = A;
	   end
	   else begin
	      NS = B;
	   end
	end
      endcase // case (CS)
   end   

endmodule: receiveSerial

/*
 * Waits for 3 consecutive idle's on the line.
 * 
 */
module wait_idle
  (input logic clk, rst_L,
   input logic bit_in,
   input logic start,
   output logic done);

   logic 	cl_ct, inc_ct;
   logic [1:0] 	count;

   counter #(2) ctr(.clk(clk), .rst_L(rst_L), .ld(1'b0), .cl(cl_ct),
		    .inc(inc_ct), .dec(1'b0), .D(2'b0), .Q(count));

   enum 		 logic {A = 1'd0, B = 1'd1} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= A;
      else
	CS <= NS;
   end

   always_comb begin
      inc_ct = 0; cl_ct = 0; done = 0;
      case(CS)
	A: begin
	   if(start) begin
	      inc_ct = $isunknown(bit_in);
	      NS = B;
	   end
	   else begin
	      NS = A;
	   end
	end

	B: begin
	   if(count == 3) begin
	      cl_ct = 1; done = 1;
	      NS = A;
	   end
	   else if($isunknown(bit_in)) begin
	      inc_ct = 1;
	      NS = B;
	   end
	   else if(~$isunknown(bit_in)) begin
	      cl_ct = 1;
	      NS = B;
	   end
	   else begin
	      NS = B;
	   end
	end
	
      endcase // case (CS)
   end
   

endmodule: wait_idle


/*
 * Receives the bits on the line and runs it through the CRC16.
 * 
 */
module receive_crc16
  (input logic clk, rst_L,
   input logic bit_in, bit_in_valid,
   input logic start, clr_crc,
   output logic done,
   output logic [15:0] crc16);

   logic 	       ld_ct, dec_ct;
   logic [6:0] 	       count;
   
   counter #(7, 80) ctr(.clk(clk), .rst_L(rst_L), .ld(ld_ct), .cl(1'b0),
			.inc(1'b0), .dec(dec_ct), .D(7'd80), .Q(count));

   logic 	       shift;
   
   crc16_datapath crc(.clk(clk), .rst_L(rst_L), .bit_in(bit_in), .shift(shift),
		      .clr(clr_crc), .rem(crc16));

   enum 	       logic {A = 1'd0, B = 1'd1} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= A;
      else
	CS <= NS;
   end

   always_comb begin
      done = 0; shift = 0; ld_ct = 0; dec_ct = 0;
      case(CS)
	A: begin
	   if(start) begin
	      shift = 1; dec_ct = 1;
	      NS = B;
	   end
	   else begin
	      NS = A;
	   end
	end

	B: begin
	   if(count != 7'd0 & bit_in_valid) begin
	      shift = 1; dec_ct = 1;
	      NS = B;
	   end
	   else if(count == 7'd0 & bit_in_valid) begin
	      done = 1; ld_ct = 1;
	      NS = A;
	   end
	   else begin
	      NS = B;
	   end
	end
      endcase // case (CS)
   end

endmodule: receive_crc16

module crc5_datapath
  (input logic clk, rst_L,
   input logic bit_in, shift, clr,
   output logic [4:0] rem);

   logic 	      x0_in, x0_out,
		      x1_in, x1_out,
		      x2_in, x2_out,
		      x3_in, x3_out,
		      x4_in, x4_out;
   
   register #(1, 1, 1) x0
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x0_in), .Q(x0_out));
   
   register #(1, 1, 1) x1
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x1_in), .Q(x1_out));
   
   register #(1, 1, 1) x2
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x2_in), .Q(x2_out));
   
   register #(1, 1, 1) x3
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x3_in), .Q(x3_out));
   
   register #(1, 1, 1) x4
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x4_in), .Q(x4_out));

   assign x0_in = bit_in ^ x4_out;
   assign x1_in = x0_out;
   assign x2_in = x0_in ^ x1_out;
   assign x3_in = x2_out;
   assign x4_in = x3_out;
   assign rem = {x4_out, x3_out, x2_out, x1_out, x0_out};

endmodule: crc5_datapath

module crc16_datapath
  (input logic clk, rst_L,
   input logic bit_in, shift, clr,
   output logic [15:0] rem);    

   logic 	       x0_in, x0_out,
		       x1_in, x1_out,
		       x2_in, x2_out,
		       x3_in, x3_out,
		       x4_in, x4_out,
		       x5_in, x5_out,
		       x6_in, x6_out,
		       x7_in, x7_out,
		       x8_in, x8_out,
		       x9_in, x9_out,
		       x10_in, x10_out,
		       x11_in, x11_out,
		       x12_in, x12_out,
		       x13_in, x13_out,
		       x14_in, x14_out,
		       x15_in, x15_out;
   
   register #(1, 1, 1) x0
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x0_in), .Q(x0_out));
   
   register #(1, 1, 1) x1
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x1_in), .Q(x1_out));
   
   register #(1, 1, 1) x2
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x2_in), .Q(x2_out));
   
   register #(1, 1, 1) x3
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x3_in), .Q(x3_out));
   
   register #(1, 1, 1) x4
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x4_in), .Q(x4_out));

   register #(1, 1, 1) x5
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x5_in), .Q(x5_out));
   
   register #(1, 1, 1) x6
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x6_in), .Q(x6_out));
   
   register #(1, 1, 1) x7
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x7_in), .Q(x7_out));
   
   register #(1, 1, 1) x8
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x8_in), .Q(x8_out));
   
   register #(1, 1, 1) x9
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x9_in), .Q(x9_out));

   register #(1, 1, 1) x10
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x10_in), .Q(x10_out));
   
   register #(1, 1, 1) x11
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x11_in), .Q(x11_out));
   
   register #(1, 1, 1) x12
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x12_in), .Q(x12_out));
   
   register #(1, 1, 1) x13
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x13_in), .Q(x13_out));
   
   register #(1, 1, 1) x14
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x14_in), .Q(x14_out));

   register #(1, 1, 1) x15
     (.clk(clk), .rst_L(rst_L), .ld(shift), .cl(clr),
      .D(x15_in), .Q(x15_out));

   assign x0_in = bit_in ^ x15_out;
   assign x1_in = x0_out;
   assign x2_in = x0_in ^ x1_out;
   assign x3_in = x2_out;
   assign x4_in = x3_out;
   assign x5_in = x4_out;
   assign x6_in = x5_out;
   assign x7_in = x6_out;
   assign x8_in = x7_out;
   assign x9_in = x8_out;
   assign x10_in = x9_out;
   assign x11_in = x10_out;
   assign x12_in = x11_out;
   assign x13_in = x12_out;
   assign x14_in = x13_out;
   assign x15_in = x0_in ^ x14_out;
   assign rem = {x15_out, x14_out, x13_out, x12_out, x11_out,
		 x10_out, x9_out, x8_out, x7_out, x6_out, x5_out,
		 x4_out, x3_out, x2_out, x1_out, x0_out};

endmodule: crc16_datapath

/*
 * Stuffs a 0 on the line after every six consecutive 1's.
 * 
 */
module bitStuff
  (input logic clk, rst_L,
   input logic stuff_start, stuff_stop,
   input logic bit_in, bit_in_valid,
   output logic bit_out, bit_out_valid,
   output logic stuffing);

   assign bit_out_valid = stuffing ? 1 : bit_in_valid;
   assign bit_out = stuffing ? 0 : bit_in;

   logic 	cl_ct, inc_ct;
   logic [2:0] 	count;

   counter #(3) ct(.clk(clk), .rst_L(rst_L), .ld(1'b0), .cl(cl_ct),
		   .inc(inc_ct), .dec(1'b0), .D(3'd0), .Q(count));

   enum 	logic [1:0] {s1 = 2'd0, s2 = 2'd1, s3 = 2'd2, s4 = 2'd3} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= s1;
      else
	CS <= NS;
   end

   always_comb begin
      stuffing = 0; cl_ct = 0; inc_ct = 0;
      case(CS)
	s1: begin
	   if(stuff_start & bit_in_valid & bit_in) begin
	      inc_ct = 1;
	      NS = s2;
	   end
	   else if(stuff_start & bit_in_valid & ~bit_in) begin
	      cl_ct = 1;
	      NS = s2;
	   end
	   else begin
	      NS = s1;
	   end
	end

	s2: begin
	   if(stuff_stop) begin
	      cl_ct = 1;
	      NS = s1;
	   end
	   else if(bit_in_valid & bit_in & count == 3'd5) begin
	      NS = s3;
	   end
	   else if(bit_in_valid & bit_in) begin
	      inc_ct = 1;
	      NS = s2;
	   end
	   else if(bit_in_valid & ~bit_in) begin
	      cl_ct = 1;
	      NS = s2;
	   end
	   else begin
	      NS = s2;
	   end
	end

	s3: begin
	   stuffing = 1; cl_ct = 1;
	   NS = s2;
	end

      endcase // case (CS)
   end // always_comb begin   

endmodule: bitStuff

/*
 * Ignores the next bit after every six consecutive 1's it encounters.
 * 
 */
module unStuff
  (input logic clk, rst_L,
   input logic start, stop,
   input logic bit_in,
   output logic bit_out, bit_out_valid);

   logic 	unstuffing;

   assign bit_out_valid = ~unstuffing;
   assign bit_out = bit_in;

   logic 	cl_ct, inc_ct;
   logic [2:0] 	count;

   counter #(3) ct(.clk(clk), .rst_L(rst_L), .ld(1'b0), .cl(cl_ct),
		   .inc(inc_ct), .dec(1'b0), .D(3'd0), .Q(count));

   enum 	logic {A = 1'b0, B = 1'b1} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= A;
      else
	CS <= NS;
   end

   always_comb begin
      unstuffing = 0; cl_ct = 0; inc_ct = 0;
      case(CS)
	A: begin
	   if(start & bit_in) begin
	      inc_ct = 1;
	      NS = B;
	   end
	   else if(start & ~bit_in) begin
	      cl_ct = 1;
	      NS = B;
	   end
	   else begin
	      NS = A;
	   end
	end

	B: begin
	   if(count == 3'd6) begin
	      unstuffing = 1; cl_ct = 1;
	      NS = B;
	   end
	   else if(stop) begin
	      cl_ct = 1;
	      NS = A;
	   end
	   else if(bit_in) begin
	      inc_ct = 1;
	      NS = B;
	   end
	   else if(~bit_in) begin
	      cl_ct = 1;
	      NS = B;
	   end
	   else begin
	      NS = B;
	   end
	end
      endcase // case (CS)
   end
   
endmodule: unStuff

module nrzi
  (input logic clk, rst_L,
   input logic bit_in, bit_in_valid,
   output logic J, K, SE0);

   enum 	logic [1:0] {s1 = 2'd0, s2 = 2'd1, s3 = 2'd2, s4 = 2'd3} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= s1;
      else
	CS <= NS;
   end

   always_comb begin
      J = 0; K = 0; SE0 = 0;
      case(CS)
	s1: begin
	   if(bit_in_valid & (bit_in == 1'b1)) begin
	      J = 1;
	      NS = s1;
	   end
	   else if(bit_in_valid & (bit_in == 1'b0)) begin
	      K = 1;
	      NS = s2;
	   end
	   else if(bit_in_valid) begin
	      SE0 = 1;
	      NS = s3;
	   end
	   else begin
	      NS = s1;
	   end
	   
	end

	s2: begin
	   if(bit_in_valid & (bit_in == 1'b1)) begin
	      K = 1;
	      NS = s2;
	   end
	   else if(bit_in_valid & (bit_in == 1'b0)) begin
	      J = 1;
	      NS = s1;
	   end
	   else if(bit_in_valid) begin
	      SE0 = 1;
	      NS = s3;
	   end
	   else begin
	      NS = s2;
	   end
	end

	s3: begin
	   SE0 = 1;
	   NS = s4;
	end

	s4: begin
	   J = 1;
	   NS = s1;
	end

      endcase // case (CS)
   end // always_comb begin
   

endmodule: nrzi

module unnrzi
  (input logic clk, rst_L,
   input logic J, K, SE0,
   output logic bit_out);

   enum 	logic {prevJ = 1'b0, prevK = 1'b1} CS, NS;

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	CS <= prevJ;
      else
	CS <= NS;
   end

   always_comb begin
      bit_out = 1'bx;
      case(CS)
	prevJ: begin
	   if(SE0) begin
	      bit_out = 1'bx;
	      NS = prevJ;
	   end
	   else if(J) begin
	      bit_out = 1'b1;
	      NS = prevJ;
	   end
	   else if(K) begin
	      bit_out = 1'b0;
	      NS = prevK;
	   end
	   else begin
	      NS = prevJ;
	   end
	end

	prevK: begin
	   if(SE0) begin
	      bit_out = 1'bx;
	      NS = prevJ;
	   end
	   else if(J) begin
	      bit_out = 1'b0;
	      NS = prevJ;
	   end
	   else if(K) begin
	      bit_out = 1'b1;
	      NS = prevK;
	   end
	   else begin
	      NS = prevK;
	   end
	end // case: prevK
      endcase // case (CS)
   end
   
endmodule: unnrzi

module dpdm
  (input logic J, K, SE0,
   inout tri0 DP, DM);

   logic      dp_en, dm_en, dp_val, dm_val;

   assign dp_en = J | K | SE0;
   assign dm_en = J | K | SE0;

   assign dp_val = J;
   assign dm_val = K;

   assign DP = dp_en ? dp_val : 1'bz;
   assign DM = dm_en ? dm_val : 1'bz;
   
endmodule: dpdm

module undpdm
  (inout tri0 DP, DM,
   output logic J, K, SE0);

   always_comb begin
      J = 0; K = 0; SE0 = 0;
      if(DP & ~DM)
	J = 1;
      else if(~DP & DM)
	K = 1;
      else
	SE0 = 1;
   end

endmodule: undpdm

module register
  #(parameter W = 32, R = 0, CL = 0)
   (input logic clk, rst_L, ld, cl,
    input logic [W-1:0] D,
    output logic [W-1:0] Q);

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	Q <= R;
      else if(cl)
	Q <= CL;
      else if(ld)
	Q <= D;
   end

endmodule: register

module shifter
  #(parameter W = 32, R = 0)
   (input logic clk, rst_L, ld, cl,
    input logic sr, sl,
    input logic [W-1:0] D,
    output logic [W-1:0] Q);

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	Q <= R;
      else if(cl)
	Q <= 'b0;
      else if(ld)
	Q <= D;
      else if(sr)
	Q <= Q >> 1;
      else if(sl)
	Q <= Q << 1;
   end

endmodule: shifter

module shift_in
  #(parameter W = 32)
   (input logic clk, rst_L, shift, cl,
    input logic in,
    output logic [W-1:0] Q);

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	Q <= 'b0;
      else if(cl)
	Q <= 'b0;
      else if(shift)
	Q <= {in, Q[W-1:1]};
   end

endmodule: shift_in


module counter
  #(parameter W = 32, R = 0)
   (input logic clk, rst_L, ld, cl, inc, dec,
    input logic [W-1:0] D,
    output logic [W-1:0] Q);

   always_ff @(posedge clk, negedge rst_L) begin
      if(~rst_L)
	Q <= R;
      else if(cl)
	Q <= 'b0;
      else if(ld)
	Q <= D;
      else if(inc)
	Q <= Q + 1;
      else if(dec)
	Q <= Q - 1;
   end

endmodule: counter
