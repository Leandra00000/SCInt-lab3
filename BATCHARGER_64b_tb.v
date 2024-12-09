`timescale 1 ns/10 ps


module BATCHARGER_64b_tb;
   
   wire [63:0] vin; // input voltage; must be at least 200mV higher than vsensbat to allow iforcedbat > 0
   wire [63:0] vbat;     // battery voltage (V)
   wire [63:0] ibat;     // battery current (A)
   wire [63:0] vtbat;    // Battery temperature
   wire [63:0] dvdd;  // digital supply
   wire [63:0] dgnd;  // digital ground
   wire [63:0] pgnd;  // power ground		       

                    
   reg         en;   // enables the module
   reg [3:0]   sel;  // battery capacity selection bits: b[3,2,1,0] weights are 400,200,100,50 mAh + offset of 50mAh covers the range from 50 up to 800 mAh 
   
   
   real        rl_dvdd, rl_dgnd, rl_pgnd;
   real        rl_ibat, rl_vbat, rl_vtbat;
   real        rl_vin;         // converted value of vin to real 

   reg [63:0] vbat_prev;
   
BATCHARGER_64b uut(
		   .iforcedbat(ibat), // output current to battery
		   .vsensbat(vbat), // voltage sensed (obtained at the battery as "voltage from iforcedbat integration" + ESR * iforcedbat)
		   .vin(vin), // input voltage; must be at least 200mV higher than vsensbat to allow iforcedbat > 0
		   .vbattemp(vtbat),	// voltage that represents the battery temperature -40ºC to 125ºC -> 0 to 0.5V	   
		   .en(en),     // block enable control
		   .sel(sel), // battery capacity selection bits: b[3,2,1,0] weights are 400,200,100,50 mAh + offset of 50mAh covers the range from 50 up to 800 mAh 
		   .dvdd(dvdd), // digital supply
		   .dgnd(dgnd), // digital ground
		   .pgnd(pgnd)  // power ground		       

);   

   
BATCHARGERlipo lipobattery(
		   .vbat(vbat),     // battery voltage (V)
		   .ibat(ibat),     // battery current (A)
		   .vtbat(vtbat)    // Battery temperature
		   );
   


initial
  begin
     rl_vin = 4.5;
     rl_pgnd = 0.0;
     sel[3:0] = 4'b1000;  // 450mAh selection     
     en = 1'b1;
     
     #5010
     $display("Starting battery current");
     if (ibat!=64'h3FA69446_7381D7DC) begin
        $display("Starting battery current incorrect: %d",ibat);
        $finish();
     end
     $display("battery current correct");

     #200500
     $display("Entering cc mode");
     if (ibat!=64'h3FCCAF4F_0D844D01) begin
        $display("Incorrect current in cc mode : %d",ibat);
        $finish();
     end
     $display("cc mode is correct");
     
     #4532500
     $display("Entering cv mode");
     if (ibat==64'h3FCCAF4F_0D844D01) begin
        $display("Incorrect current in cv mode : %d",ibat);
        $finish();
     end
     $display("cv mode is correct");
     
     #8732500
     
     
     $display("SUCCESS!");
     
     #10000000;     
     #10000000 $finish;
     
  end
   

  

//-- Signals conversion ---------------------------------------------------
   initial assign rl_vbat = $bitstoreal(vbat);
   initial assign rl_vtbat = $bitstoreal(vtbat);
   initial assign rl_ibat = $bitstoreal(ibat);
   initial assign rl_dvdd = $bitstoreal(dvdd);
   initial assign rl_dgnd = $bitstoreal(dgnd);   
   
   
   assign vin = $realtobits(rl_vin);
   assign pgnd = $realtobits(rl_pgnd);
   
endmodule
