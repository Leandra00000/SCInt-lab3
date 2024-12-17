`timescale 1ns / 1ps


module BATCHARGERctr_tb;

   

   wire  cc; // output to analog block: constant current mode with ich current
   wire  tc; // output to analog block: trickle mode with 0.1 x ich current
   wire  cv; // output to analog block: constant voltage mode vpreset voltage
   wire  imonen; //enables current monitor
   wire  vmonen; //enables voltage monitor
   wire  tmonen; //enables temperature monitor				
   reg [7:0] vbat; // 8 bits data from adc with battery voltage; vbat = adc(vref=0.5V, battery_voltage /10)
   reg [7:0] ibat; // 8 bits data from adc with battery current; ibat = adc(vref=0.5V, battery_current * Rsens); Rsens = 1/C ; C=nominal capacity of battery; vadc(Ibat=0.5C)=0.5V
   reg [7:0] tbat; // 8 bits data from adc with battery temperature; vadc = Temp/330 + 20/165 ; tbat = adc(vref=0,5, vadc)
   reg [7:0] vcutoff; // constant from OTP: voltage threshold for exiting trickle mode
   reg [7:0] vpreset; // constant from OTP: voltage for constant voltage mode
   reg [7:0] tempmin; // constant from OTP: minimum temperature
   reg [7:0] tempmax; // constant from OTP: maximum temperature
   reg [7:0] tmax; // constant from OTP: maximum charge time
   reg [7:0] iend; // charge current to be used as "end charging" end criteria
   reg 	     clk; // state machine clock
   reg       en;
   wire si;
   wire se;
   wire so;
   reg 	     rstz; // system reset
   reg 	     vtok; // singals that voltage and temperature values are valid
   wire      dvdd;  // digital supply
   wire      dgnd;  // digital ground

   integer i;
   
   reg dvdd_reg, dgnd_reg;
   
   assign dvdd = dvdd_reg;
   assign dgnd = dgnd_reg;


   parameter start=0, wait1=1, end1=2, ccmode=3, tcmode=4, cvmode=5; 
   
BATCHARGERctr uut(   
		     .cc(cc), 
		     .tc(tc), 
		     .cv(cv),
		     .vtok(vtok),
		     .imonen(imonen), 
		     .vmonen(vmonen), 
		     .tmonen(tmonen), 
		     .vbat(vbat), 
		     .ibat(ibat), 
		     .tbat(tbat), 
		     .vcutoff(vcutoff), 
		     .vpreset(vpreset), 
		     .tempmin(tempmin), 
		     .tempmax(tempmax), 
		     .tmax(tmax), 
		     .iend(iend), 
		     .clk(clk),
~		     .si(si),
                     .se(se),
                     .so(so), 
		     .rstz(rstz),
		     .en(en),
		     .dvdd(dvdd),
                     .dgnd(dgnd)		     
		     );


   initial 
     begin
        clk=0;
	    vtok = 0;
        rstz = 0;    // active 0 reset at the begining
        en=1;
    
    dvdd_reg=1;
    dgnd_reg=0;
	vbat[7:0] = 8'b10011001 ; // Vbat=3V -> after resistor divider: 0.3V -> adc with Vref=0.5V:  vabt=8'b10011001 
	ibat[7:0] = 8'b01100110 ; // 8 bits data from adc with battery current: 0.2*C
	tbat[7:0] = 8'b01100100 ; // 8 bits data from adc with battery temperature: 25ºC -> 0.2V -> adc with Vref=0.5V:  tbat=8'b01100100
	vcutoff[7:0] = 8'b10100011; // constant from OTP: voltage threshold for exiting trickle mode; Vcutoff=3.2V 
	vpreset[7:0] = 8'b11000111; // constant from OTP: voltage for constant voltage mode; Vpreset=3.9V
	tempmin[7:0] = 8'b00101110; // constant from OTP: minimum temperature: -10ºC
	tempmax[7:0] = 8'b10001011; // constant from OTP: maximum temperature: 50ºC
	tmax[7:0] = 8'b00001000; // constant from OTP: maximum charge time (units of 255 clock periods): 255*8 = 2040 clock periods 
	iend[7:0] = 8'b00110011; // charge current div by 10 to be used as charging end criteria: 0.1C 
	

	
	#12 rstz = 1;   // reset end
        vtok = 1; // voltage and temperature values are valid
	
	// with Vbat < Vcutoff -> tc mode is expected

	$display ( "Vbat < Vcutoff, waiting trickle charge mode");
	#20 if (tc==0 || cc==1 || cv==1) begin
           $display( "Error: Expected trickle charge mode. Expected tc=1, cc=0 and cv=0 but got tc=%d, cc=%d, cv=%d", tc,cc,cv);
           if(cc==1) begin
               $display( "Error: Expected trickle charge mode but it is in constant current mode");
           end 
           if(cv==1) begin
               $display( "Error: Expected trickle charge mode but it is in constant voltage mode");
           end 
           $finish();
        end
        
        if (imonen==1) begin
            $display( "Error: Expected current monitor disabled");
            $finish();
        end
        
        if (vmonen==0) begin
           $display( "Error: Expected voltage monitor enabled");
           $finish();
        end
        if (tmonen==0) begin
           $display( "Error: Expected temperature monitor enabled");
           $finish();
        end
        
	$display ( "SUCCESS: currently in trickle charge mode");

	#100  vbat[7:0] = 8'b10100100 ; // Vbat=vcutoff +1 to exit tc mode

	$display ( "Vbat > Vcutoff waiting cc mode");
	#20 if (cc==0 || tc==1 || cv==1) begin
	   $display( "Error: Expected constant current mode. Expected tc=0, cc=1 and cv=0 but got tc=%d, cc=%d, cv=%d", tc,cc,cv);
       if(tc==1) begin
           $display( "Error: Expected constant current mode but it is in trickle charge mode");
       end 
       if(cv==1) begin
           $display( "Error: Expected constant current mode but it is in constant voltage mode");
       end 
       $finish();
	end
	if (imonen==1) begin
        $display( "Error: Expected current monitor disabled");
        $finish();
    end
    
    if (vmonen==0) begin
       $display( "Error: Expected voltage monitor enabled");
       $finish();
    end
    if (tmonen==0) begin
       $display( "Error: Expected temperature monitor enabled");
       $finish();
    end
        
	$display ( "SUCCESS: currently in constant current mode");

	#100  vbat[7:0] = 8'b11001000 ; // Vbat=preset +1 to exit cc mode

	$display ( "Vbat > Vpreset, waiting cv mode");
	#20 if (cv==0 || cc==1 || tc==1) begin
	   $display( "Error: Expected constant voltage mode. Expected tc=0, cc=0 and cv=1 but got tc=%d, cc=%d, cv=%d", tc,cc,cv);
       if(tc==1) begin
           $display( "Error: Expected constant voltage mode but it is in trickle charge mode");
       end 
       if(cc==1) begin
           $display( "Error: Expected constant voltage mode but it is in constant current mode");
       end 
       $finish();
	end
	
	if (imonen==0) begin
        $display( "Error: Expected current monitor enabled");
        $finish();
    end
    
    if (vmonen==1) begin
       $display( "Error: Expected voltage monitor disabled");
       $finish();
    end
    if (tmonen==0) begin
       $display( "Error: Expected temperature monitor enabled");
       $finish();
    end
	$display ( "SUCCESS: currently in constant voltage mode");

    $display("Checking timeout for the cv mode");
    for (i=0; i<=tmax*255;i=i+1)  begin
      if (cv == 0) begin
         $display("Error: timeout didn't finish %d",i);
         $finish();
      end
      @(negedge clk);    // waits for the negative edge of clk $
    end 
    
    
    if (cv==1 || cc==1 || tc==1) begin
	   $display( "Error: Expected constant voltage mode. Expected tc=0, cc=0 and cv=0 but got tc=%d, cc=%d, cv=%d", tc,cc,cv);
       if(tc==1) begin
           $display( "Error: Expected no mode but it is in trickle charge mode");
       end 
       if(cv==1) begin
           $display( "Error: Expected no mode but it is in constant voltage mode");
       end 
       if(cc==1) begin
           $display( "Error: Expected no mode but it is in constant current mode");
       end 
       $finish();
	end
	
	if (imonen==1) begin
        $display( "Error: Expected current monitor disabled");
        $finish();
    end
    
    if (vmonen==0) begin
       $display( "Error: Expected voltage monitor enabled");
       $finish();
    end
    if (tmonen==1) begin
       $display( "Error: Expected temperature monitor enabled");
       $finish();
    end
    
    $display("SUCCESS: left cv mode by timeout. finished first cycle");
	
	#10  vbat[7:0] = 8'b11000110 ; // Vbat=preset -1 to return to cc mode

	$display ( "voltage reduced, Vbat < Vpreset, waiting cc mode");
	#20 if (cc==0 || tc==1 || cv==1) begin
	   $display( "Error: Expected constant current mode. Expected tc=0, cc=1 and cv=0 but got tc=%d, cc=%d, cv=%d", tc,cc,cv);
       if(tc==1) begin
           $display( "Error: Expected constant current mode but it is in trickle charge mode");
       end 
       if(cv==1) begin
           $display( "Error: Expected constant current mode but it is in constant voltage mode");
       end 
       $finish();
	end
	if (imonen==1) begin
        $display( "Error: Expected current monitor disabled");
        $finish();
    end
    
    if (vmonen==0) begin
       $display( "Error: Expected voltage monitor enabled");
       $finish();
    end
    if (tmonen==0) begin
       $display( "Error: Expected temperature monitor enabled");
       $finish();
    end
        
	$display ( "SUCCESS: currently in constant current mode");

	#100  vbat[7:0] = 8'b11001000 ; // Vbat=preset +1 to exit cc mode

	$display ( "Vbat > Vpreset, waiting cv mode");
	#20 if (cv==0 || cc==1 || tc==1) begin
	   $display( "Error: Expected constant voltage mode. Expected tc=0, cc=0 and cv=1 but got tc=%d, cc=%d, cv=%d", tc,cc,cv);
       if(tc==1) begin
           $display( "Error: Expected constant voltage mode but it is in trickle charge mode");
       end 
       if(cc==1) begin
           $display( "Error: Expected constant voltage mode but it is in constant current mode");
       end 
       $finish();
	end
	
	if (imonen==0) begin
        $display( "Error: Expected current monitor enabled");
        $finish();
    end
    
    if (vmonen==1) begin
       $display( "Error: Expected voltage monitor disabled");
       $finish();
    end
    if (tmonen==0) begin
       $display( "Error: Expected temperature monitor enabled");
       $finish();
    end
	$display ( "SUCCESS: currently in constant voltage mode");


	#100  ibat[7:0] = 8'b00110010 ; // ibat < 0.1 C
	$display( "Attempt to leave cv mode by minimum current");
	#20 if (cv==1 || cc==1 || tc==1) begin
	   $display( "Error: Expected constant voltage mode. Expected tc=0, cc=0 and cv=0 but got tc=%d, cc=%d, cv=%d", tc,cc,cv);
       if(tc==1) begin
           $display( "Error: Expected no mode but it is in trickle charge mode");
       end 
       if(cv==1) begin
           $display( "Error: Expected no mode but it is in constant voltage mode");
       end 
       if(cc==1) begin
           $display( "Error: Expected no mode but it is in constant current mode");
       end 
       $finish();
	end
	
	if (imonen==1) begin
        $display( "Error: Expected current monitor disabled");
        $finish();
    end
    
    if (vmonen==0) begin
       $display( "Error: Expected voltage monitor enabled");
       $finish();
    end
    if (tmonen==1) begin
       $display( "Error: Expected temperature monitor enabled");
       $finish();
    end
	$display( "exit cv by minimum current");
	
	#10  vbat[7:0] = 8'b11000110 ; // Vbat=preset -1 to return to cc mode
	#20  tbat[7:0] = 8'b11100100;
	$display( "Checking sensitivity to temperature");
    #20    if (tc==1 || cc==1 || cv==1) begin
           $display( "Error: There shouldn't be any mode selected");
           $finish();
        end
	
	$display( "SUCCESS: test finished with success");
	#1000
	
 	
	$finish;
     end
   
   always
     #5 clk = ~clk; 




   
endmodule // charger_tb


    
