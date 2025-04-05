// readrequnit.v


//-----------------------------------------------------------------------
//-
//- Entity name :ReadReqUnit
//-
//-----------------------------------------------------------------------
`timescale 1ns / 100ps
`define idle 2'b00
`define initreadreq 2'b01
`define rdNdataLsb 2'b10
`define runtx      2'b11



 module readrequnit(
   
   // signaux systèmes
    clk,
    n_reset,
    
   // interface avec le périphérique
    read_req,
    n_read,
    data,
    n_wait,
    
    //interface avec interrupt unit

    interrupt,

   //interface avec txunit
    
    txbusy,
    NdataLsb,
    runtx,
    endtx,
   // interface avec rxunit
    
    rxbusy,

   // autres modules
    
    busyreadreq
    );


 input clk;
 input n_reset;
 input read_req;
 output n_read;
 input [7:0] data;
 input n_wait;
 input interrupt;
 input txbusy;
 output [7:0] NdataLsb;
 output runtx;
 input endtx;
 input rxbusy;
 output busyreadreq;


// sorties 

 reg n_read;
 reg [7:0] NdataLsb;
 reg runtx;
 reg busyreadreq;

// signaux internes

reg [1:0] rdreq_presentstate, rdreq_nextstate;
reg NdataLsb_ok_s;
wire NdataLsb_ok;
reg n_read_r;
reg read_req_latch;
reg read_req_r;


reg busyreadreq_i;
reg runtx_i;
reg n_read_i;

 //-----------------------------------------------------------------------//
 //-                        FSM READREQUEST STATE                        -// 
 //-----------------------------------------------------------------------//
 
 always @(rdreq_presentstate or read_req_latch or rxbusy or txbusy 
         or interrupt or NdataLsb_ok or endtx )
  begin : rdreq_nextstate_logic
   case (rdreq_presentstate)
    
    `idle : begin 
             if( read_req_latch == 1'b1 && rxbusy == 1'b0 && txbusy == 1'b0 && interrupt == 1'b0)
              rdreq_nextstate <= `initreadreq;
             else
              rdreq_nextstate <= `idle;
             end

    `initreadreq : rdreq_nextstate <= `rdNdataLsb;
     
    `rdNdataLsb : begin
                 if(NdataLsb_ok == 1'b1)
                  rdreq_nextstate <= `runtx;
                 else
                  rdreq_nextstate <= `rdNdataLsb;
                 end

    `runtx : begin
              if( endtx == 1'b1)
               rdreq_nextstate <= `idle;
              else
               rdreq_nextstate <= `runtx;
              end
    default : rdreq_nextstate <= `idle;
  endcase
end


always @(posedge clk or negedge n_reset)
begin : register_generation
 if ( n_reset == 1'b0)
  rdreq_presentstate <= `idle;
 else
  rdreq_presentstate <= rdreq_nextstate;
end
 
 //-----------------------------------------------------------------------//
 //-                        FSM READREQUEST OUTPUT                       -// 
 //-----------------------------------------------------------------------//

 always @(rdreq_nextstate or NdataLsb_ok)
 begin : output_logic
  case (rdreq_nextstate)
   `idle : begin
                    busyreadreq_i <= 1'b0;
                    runtx_i       <= 1'b0;
                    n_read_i      <= 1'b1;
                  end

   `initreadreq : begin
                    busyreadreq_i <= 1'b1;
                    runtx_i       <= 1'b0;
                    n_read_i      <= 1'b1;
                 end

   `rdNdataLsb : begin
                    busyreadreq_i <= 1'b1;
                    runtx_i       <= 1'b0;
                    if (NdataLsb_ok == 1'b1)
                     n_read_i      <= 1'b1;
                    else
                     n_read_i      <= 1'b0;
                 end
   `runtx : begin
                    busyreadreq_i <= 1'b1;
                    runtx_i       <= 1'b1;
                    n_read_i      <= 1'b1;
                  end

   default : begin
                    busyreadreq_i <= 1'b0;
                    runtx_i       <= 1'b0;
                    n_read_i      <= 1'b1;
                   end
 endcase
end

 //-----------------------------------------------------------------------//
 //-----------------------------------------------------------------------//

always @(posedge clk or negedge n_reset)
 begin : output_reg
  if( n_reset == 1'b0)
   begin
     busyreadreq <= 1'b0;
     runtx       <= 1'b0;
     n_read      <= 1'b1;
   end else
    begin
     busyreadreq <= busyreadreq_i;
     runtx       <= runtx_i;
     n_read      <= n_read_i;
    end
end


 //-----------------------------------------------------------------------//
 //-                        synchronisation                              -// 
 //-----------------------------------------------------------------------//
 always @(posedge clk or negedge n_reset)
  begin
   if(n_reset == 1'b0)
   begin
    n_read_r  <= 1'b1;
    read_req_r <= 1'b1;
  end 
  else begin
    n_read_r  <= n_read;
    read_req_r <= read_req;
  end
 end

//-----------------------------------------------------------------------//
//-                        read_req_latch                               -// 
//-----------------------------------------------------------------------//
  always@(posedge clk or negedge n_reset)
  begin
   if(n_reset == 1'b0)
      read_req_latch <= 1'b0;
   else if ( read_req == 1'b1 && read_req_r == 1'b0)
     read_req_latch <= 1'b1;
   else if( runtx == 1'b1)
     read_req_latch <= 1'b0;
   end

//-----------------------------------------------------------------------//
//-                        NdataLsb_ok                                  -// 
//-----------------------------------------------------------------------//

  always@(posedge clk or negedge n_reset)
  begin
   if(n_reset == 1'b0)
    NdataLsb_ok_s <= 1'b0;
   else if ( n_read_r == 1'b0 && n_wait == 1'b1)
    NdataLsb_ok_s <= 1'b1;
   else
    NdataLsb_ok_s <= 1'b0;
  end

assign NdataLsb_ok= NdataLsb_ok_s | (~n_read_r & n_wait);
//-----------------------------------------------------------------------//
//-                        NdataLsb                                     -// 
//-----------------------------------------------------------------------//

always @(posedge clk or negedge n_reset)
 begin
  if ( n_reset == 1'b0)
   NdataLsb <= 8'b00000000;
  else if ( rdreq_presentstate == `rdNdataLsb)
   NdataLsb <= data;
 end

 //-----------------------------------------------------------------------//
 //-                        FIN                                          -// 
 //-----------------------------------------------------------------------//



endmodule