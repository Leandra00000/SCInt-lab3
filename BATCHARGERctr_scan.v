module BATCHARGERctr (
    output cc,         // output to analog block: constant current mode with ich current
    output tc,         // output to analog block: trickle mode with 0.1 x ich current
    output cv,         // output to analog block: constant voltage mode vpreset voltage
    output imonen,     //enables current monitor
    output vmonen,     //enables voltage monitor
    output tmonen,     //enables temperature monitor
    input            si,
    input            se,
    output           so,
    input [7:0] vbat,  // 8 bits data from adc with battery voltage; vbat = adc(vref=0.5V, battery_voltage /10)
    input [7:0] ibat,  // 8 bits data from adc with battery current; ibat = adc(vref=0.5V, battery_current * Rsens); Rsens = 1/C ; C=nominal capacity of battery; vadc(Ibat=0.5C)=0.5V
    input [7:0] tbat,  // 8 bits data from adc with battery temperature; vadc = Temp/330 + 20/165 ; tbat = adc(vref=0,5, vadc)
    input [7:0] vcutoff, // constant from OTP: voltage threshold for exiting trickle mode
    input [7:0] vpreset, // constant from OTP: voltage for constant voltage mode
    input [7:0] tempmin, // constant from OTP: minimum temperature
    input [7:0] tempmax, // constant from OTP: maximum temperature
    input [7:0] tmax,    // constant from OTP: maximum charge time
    input [7:0] iend,    // charge current to be used as "end charging" end criteria
    input clk,           // state machine clock
    input en,          
    input rstz,          // system reset
    input vtok,        // singals that voltage and temperature values are valid
    input dvdd,          // digital supply
    input dgnd           // digital ground
);
   
    reg [2:0] state; 
    reg [2:0] next_state;        
    reg [15:0] charge_timer; 
    reg cc_reg, tc_reg, cv_reg, imonen_reg,vmonen_reg,tmonen_reg;

    parameter start = 0, wait1 = 1, end1  = 2, ccmode = 3, tcmode = 4, cvmode = 5;

    assign cc = cc_reg;
    assign tc = tc_reg;
    assign cv = cv_reg;
    

    assign imonen = imonen_reg; 
    assign vmonen = vmonen_reg; 
    assign tmonen = tmonen_reg; 

    // Reset and initialization
    always @(negedge clk or negedge rstz) begin
        if (!rstz) begin
            state <= start; 
            charge_timer <= 16'd0; 
            cc_reg <= 1'b0;
            tc_reg <= 1'b0;
            cv_reg <= 1'b0;
            imonen_reg <=1'b0;
            vmonen_reg <= 1'b1;
            tmonen_reg <= 1'b1;
        end else begin
            if(vtok && en && !dgnd && dvdd) begin   
                if (state == cvmode) begin
                    charge_timer <= charge_timer + 16'd1; 
                end else begin
                    charge_timer <= 16'd0; 
                end
                
                state <= next_state; 
                    
                case (next_state)
                    start: begin
                        cc_reg <= 1'b0;
                        tc_reg <= 1'b0;
                        cv_reg <= 1'b0;
                        tmonen_reg <= 1'b1;
                        imonen_reg <=1'b0;
                        vmonen_reg <= 1'b1;
                    end
                    wait1: begin
                        cc_reg <= 1'b0;
                        tc_reg <= 1'b0;
                        cv_reg <= 1'b0;
                        tmonen_reg <= 1'b1;
                        imonen_reg <=1'b0;
                        vmonen_reg <= 1'b1;
                    end
                    tcmode: begin
                        tc_reg <= 1'b1;
                        cc_reg <= 1'b0;
                        cv_reg <= 1'b0;
                        imonen_reg <= 1'b0;
                        vmonen_reg <= 1'b1;
                        tmonen_reg <= 1'b1;
                    end
                    ccmode: begin
                        tc_reg <= 1'b0;
                        cc_reg <= 1'b1;
                        cv_reg <= 1'b0;
                        imonen_reg <= 1'b0;
                        vmonen_reg <= 1'b1;
                        tmonen_reg <= 1'b1;
                    end
                    cvmode: begin
                        tc_reg <= 1'b0;
                        cc_reg <= 1'b0;
                        cv_reg <= 1'b1;
                        imonen_reg <= 1'b1;
                        vmonen_reg <= 1'b0;
                        tmonen_reg <= 1'b1;
                    end
                    end1: begin
                        tc_reg <= 1'b0;
                        cc_reg <= 1'b0;
                        cv_reg <= 1'b0;
                        imonen_reg <= 1'b0;
                        vmonen_reg <= 1'b1;
                        tmonen_reg <= 1'b0;
                    end
                    default: begin
                        tc_reg <= 1'b0;
                        cc_reg <= 1'b0;
                        cv_reg <= 1'b0;
                        imonen_reg <= 1'b0;
                        vmonen_reg <= 1'b1;
                        tmonen_reg <= 1'b1;
                    end
                endcase
            end
        end
    end
            
            
            
    always @ (*) begin
        case (state)
            start: begin
                if ((tempmin <= tbat) && (tbat <= tempmax)) begin
                    if (vbat < 8'd214) begin
                        if (vbat < vcutoff) begin
                            next_state <= tcmode;
                        end else begin
                            next_state <= ccmode;
                        end
                    end else begin
                        next_state <= end1;
                    end    
                end else begin
                    next_state <= wait1;
                end
            end

            wait1: begin
                if ((tempmin <= tbat) && (tbat <= tempmax)) begin
                    if (vbat < 8'd214) begin
                        if (vbat < vcutoff) begin
                            next_state <= tcmode;
                        end else begin
                            next_state <= ccmode;
                        end
                    end else begin
                        next_state <= end1;
                    end    
                end else begin
                    next_state <= wait1;
                end
            end

            tcmode: begin
                if ((tempmin <= tbat) && (tbat <= tempmax)) begin
                    if (vbat > vcutoff) begin
                        next_state <= ccmode; // Exit to constant current mode
                    end else begin
                        next_state <= tcmode;
                    end
                end else begin
                    next_state <= wait1;
                end
            end

            ccmode: begin
                if ((tempmin <= tbat) && (tbat <= tempmax)) begin
                    if (vbat > vpreset) begin
                        next_state <= cvmode; // Exit to constant voltage mode
                    end else begin
                        next_state <= ccmode;
                    end
                end else begin
                    next_state <= wait1;
                end
            end

            cvmode: begin
                if ((tempmin <= tbat) && (tbat <= tempmax)) begin
                    if (ibat <= iend) begin
                        next_state <= end1; // End charging
                    end else begin
                        if ((tmax * 255)<=charge_timer) begin
                            next_state <= end1;
                        end else begin
                            next_state <= cvmode;
                        end
                    end
                end else begin
                    next_state <= wait1;
                end
            end

            end1: begin
                if ((tempmin <= tbat) && (tbat <= tempmax)) begin
                    if (vbat < 8'd214) begin
                        if (vbat < vcutoff) begin
                            next_state <= tcmode;
                        end else begin
                            if (vbat < vpreset) begin
                                next_state <= ccmode; // Exit to constant voltage mode
                            end else begin
                                next_state <= end1;
                            end
                        end
                    end else begin
                        next_state <= end1;
                    end    
                end else begin
                    next_state <= wait1;
                end
            end

            default: next_state <= start; // Default to start
        endcase
    end

endmodule
