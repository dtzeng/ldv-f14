//Your testbench module
module test
  (output logic clk, rst_L);
   
   //Set up clk, rst_L, and then call your usbHost.sv tasks here  
   
   //Ex: host.prelabRequest(data);
   //    host.writeData(memPage, data, success);
   //    host.readData(memPage, data, success);
   
   initial begin
      rst_L = 1;
      rst_L <= #1 0;
      rst_L <= #2 1;
      clk = 0;
      forever #5 clk = ~clk;
   end

   logic w_success, r_success;
   logic [63:0] data;
   logic 	all_passed, uninit_passed, wr_passed, reread_passed, rewrite_passed;

   assign all_passed = uninit_passed & wr_passed & reread_passed & rewrite_passed;

   logic [15:0] test_addrs [8] = '{16'h0000, 16'h0001, 16'h0012, 16'hab00,
				   16'habcd, 16'hc0de, 16'hfffe, 16'hffff};

   logic [15:0] temp;

   initial begin
      $display("\n\n\n----------BEGIN TEST---------");
      uninit_passed <= 1; wr_passed <= 1; reread_passed <= 1; rewrite_passed <= 1;

      $display("Tesing uninitialized memory should be 0...");
      for(int i = 0; i < 8; i++) begin
	 temp = test_addrs[i];
	 #1 host.readData(temp, data, r_success);
	 if(~r_success) begin
	    $display("Read should not fail.");
	    uninit_passed <= 0;
	 end
	 
	 if(data != 64'h0) begin
	    $display("Memory at %h not zero.", temp);
	    uninit_passed <= 0;
	 end
      end
      if(uninit_passed)
	$display("Uninitialized memory test passed.\n");
      else
	$display("Uninitialized memory test failed.\n");

      
      $display("Testing writing and reading back should get back same value...");
      for(int i = 0; i < 8; i++) begin
	 temp = test_addrs[i];
	 #1 host.writeData(temp, {16'hbabe, temp, 32'h1234beef}, w_success);
	 if(~w_success) begin
	    $display("Write should not fail.");
	    wr_passed <= 0;
	 end

	 host.readData(temp, data, r_success);
	 if(~r_success) begin
	    $display("Read should not fail.");
	    wr_passed <= 0;
	 end
	 
	 if(data != {16'hbabe, temp, 32'h1234beef}) begin
	    $display("Memory read back not correct at %h", temp);
	    wr_passed <= 0;
	 end
      end
      if(wr_passed)
	$display("Write read test passed.\n");
      else
	$display("Write read test failed.\n");


      $display("Rereading to make sure read did not change value...");
      for(int i = 0; i < 8; i++) begin
	 temp = test_addrs[i];
      	 #1 host.readData(temp, data, r_success);
      	 if(~r_success) begin
      	    $display("Read should not fail.");
      	    reread_passed <= 0;
      	 end
	 
      	 if(data != {16'hbabe, temp, 32'h1234beef}) begin
      	    $display("Memory at %h changed.", temp);
      	    reread_passed <= 0;
      	 end
      end
      if(reread_passed)
      	$display("Reread memory test passed.\n");
      else
      	$display("Reread memory test failed.\n");


      $display("Rewriting to make sure values are not stuck after writing once...");
      for(int i = 0; i < 8; i++) begin
	 temp = test_addrs[i];
	 #1 host.writeData(temp, {temp, temp, temp, temp}, w_success);
	 if(~w_success) begin
	    $display("Write should not fail.");
	    rewrite_passed <= 0;
	 end

	 host.readData(temp, data, r_success);
	 if(~r_success) begin
	    $display("Read should not fail.");
	    rewrite_passed <= 0;
	 end
	 
	 if(data != {temp, temp, temp, temp}) begin
	    $display("Memory stuck/not correct at %h", temp);
	    rewrite_passed <= 0;
	 end
      end
      if(rewrite_passed)
	$display("Rewrite test passed.\n");
      else
	$display("Rewrite test failed.\n");
      

      if(all_passed)
	$display("All tests passed.\n");
      else
	$display("Not all tests passed.\n");

      $display("---------END TEST---------\n\n\n");
      
      #1 $finish;
   end
   
    

endmodule
