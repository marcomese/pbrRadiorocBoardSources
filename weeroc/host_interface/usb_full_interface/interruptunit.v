// InterruptUnit.v

//-----------------------------------------------------------------------
//-
//- Entity name : InterruptUnit
//-
//-----------------------------------------------------------------------
`timescale 1ns / 100ps

`define idle 3'b000
`define headerInterrupt 3'b001
`define trailerInterrupt 3'b010
`define rd_status_byte  3'b011
`define userInterrupt   3'b100

module interruptunit (

    // signaux système
      n_reset,
      clk,

    // Interface avec le périphérique
      interrupt,
      n_read,
      n_sync,
      n_wait,
      data,

    // Interface avec rxunit
      header_error,
      header_ok,
      trailer_error,
      rxbusy,
      
    // Interface avec txunit
      txbusy,
      header_interrupt,
      trailer_interrupt,
      status_byte,
      status_byte_ok,
      interrupt_ok,
      interrupt_latch_out,
      user_interrupt
      );


  input n_reset;
  input clk;
  input interrupt;
  output n_read;
  output n_sync;
  input n_wait;
  input [7:0] data;
  input header_error;
  input header_ok;
  input trailer_error;
  input rxbusy;
  input txbusy;
  output header_interrupt;
  output trailer_interrupt;
  output [7:0]status_byte;
  output status_byte_ok;
  input interrupt_ok;
  output interrupt_latch_out;
  output user_interrupt;
  
  // sorties du module InterruptUnit


  reg n_read;
  reg n_sync;
  reg header_interrupt;
  reg trailer_interrupt;
  reg [7:0] status_byte;
  reg status_byte_ok_s;
  wire status_byte_ok;
  reg user_interrupt;
  wire interrupt_latch_out;


 // Signaux Internes

  reg [2:0] interrupt_presentstate, interrupt_nextstate;
  reg header_error_latch;
  reg header_error_latch_r;
  reg header_error_latch_2;
  reg trailer_error_latch;
  reg interrupt_r;
  reg n_read_r;
  reg interrupt_latch;


  reg header_interrupt_i;
  reg trailer_interrupt_i;
  reg user_interrupt_i;
  reg n_read_i;

 
 //-----------------------------------------------------------------------//
 //-                        Header_error_latch                           -// 
 //-----------------------------------------------------------------------//
 always @(posedge clk or negedge n_reset)
  begin
   if (n_reset == 1'b0)
    header_error_latch_r <= 1'b0;
   else
    header_error_latch_r <= header_error_latch;
 end



 always @(posedge clk or negedge n_reset)
 begin
  if(n_reset == 1'b0)
    header_error_latch <= 1'b0;
  else 
   begin
   if (header_error == 1'b1)
     header_error_latch <= 1'b1;
   else if (header_ok == 1'b1)
     header_error_latch <= 1'b0;
   end
  end


 always @(posedge clk or negedge n_reset)
  begin
   if (n_reset == 1'b0)
    header_error_latch_2 <= 1'b0;
  else if ( header_error_latch == 1'b1 && header_error_latch_r == 1'b0) 
    header_error_latch_2 <= 1'b1;
  else if ( interrupt_ok == 1'b1 && header_interrupt == 1'b1) // fin de traitement de l'interruption header
    header_error_latch_2 <= 1'b0;
 end

//------------------------------------------------------------------------//
//-                        Trailer_error_latch                           -// 
//------------------------------------------------------------------------//

always @(posedge clk or negedge n_reset)
 begin
  if( n_reset == 1'b0)
    trailer_error_latch <= 1'b0;
  else 
   begin
   if ( trailer_error == 1'b1)
     trailer_error_latch <= 1'b1;
   if (interrupt_ok == 1'b1 && trailer_interrupt == 1'b1) // fin de traitement de l'interruption trailer
     trailer_error_latch <= 1'b0;
   end
  end

//------------------------------------------------------------------------//
//-                        interrupt_latch                               -// 
//------------------------------------------------------------------------//

always @(posedge clk or negedge n_reset)
 begin
  if ( n_reset == 1'b0)
   interrupt_latch <= 1'b0;
  else if (interrupt == 1'b1 && interrupt_r == 1'b0)
   interrupt_latch <= 1'b1;
  else if ( interrupt_ok == 1'b1 && user_interrupt == 1'b1)  // fin de traitement de l'interruption user
   interrupt_latch <= 1'b0;
 end


assign interrupt_latch_out = interrupt_latch | header_error_latch_2 | trailer_error_latch;
 
 //-----------------------------------------------------------------------//
 //-                        FSM INTERRUPT STATE                          -// 
 //-----------------------------------------------------------------------//


 always @(interrupt_presentstate or header_error_latch_2 or trailer_error_latch or interrupt_latch or 
         rxbusy or txbusy or status_byte_ok or interrupt_ok)
  begin : interrupt_nextstate_logic
   case (interrupt_presentstate)
    `idle : begin
            if( header_error_latch_2 == 1'b1 && rxbusy == 1'b0 && txbusy == 1'b0)
              interrupt_nextstate <= `headerInterrupt;
            else if ( trailer_error_latch == 1'b1 && rxbusy == 1'b0 && txbusy == 1'b0)
              interrupt_nextstate <= `trailerInterrupt;
            else if ( interrupt_latch == 1'b1 && rxbusy == 1'b0 && txbusy == 1'b0)
              interrupt_nextstate <= `rd_status_byte;
            else
              interrupt_nextstate <= `idle;
            end
     
    `headerInterrupt :  begin
            if ( interrupt_ok == 1'b1)
                interrupt_nextstate <= `idle;
            else
                interrupt_nextstate <= `headerInterrupt;
            end
     
     `trailerInterrupt : begin
            if (interrupt_ok == 1'b1)
                interrupt_nextstate <= `idle;
            else
                interrupt_nextstate <= `trailerInterrupt;
            end
      `rd_status_byte : begin
        if( status_byte_ok == 1'b1)
             interrupt_nextstate <= `userInterrupt;
        else
             interrupt_nextstate <= `rd_status_byte;
        end

      `userInterrupt : begin
            if( interrupt_ok == 1'b1)
              interrupt_nextstate <= `idle;
            else 
               interrupt_nextstate <= `userInterrupt;
            end
      default : interrupt_nextstate <= `idle;

   endcase
  end


  always @(posedge clk or negedge n_reset)
  begin :registrer_generation
   if ( n_reset == 1'b0)
    interrupt_presentstate <= `idle;
   else
    interrupt_presentstate <= interrupt_nextstate;
   end

  
 //-----------------------------------------------------------------------//
 //-                             FSM OUTPUT                              -// 
 //-----------------------------------------------------------------------//

 always @(interrupt_nextstate or status_byte_ok)
 begin : output_logic
  case (interrupt_nextstate)
   `idle : begin
               header_interrupt_i  <= 1'b0;
               trailer_interrupt_i <= 1'b0;
               user_interrupt_i    <= 1'b0;
               n_read_i            <= 1'b1;
           end
    `headerInterrupt : begin
                        header_interrupt_i  <= 1'b1;
                        trailer_interrupt_i <= 1'b0;
                        user_interrupt_i    <= 1'b0;
                        n_read_i            <= 1'b1;
                       end
    `trailerInterrupt : begin
                         header_interrupt_i  <= 1'b0;
                         trailer_interrupt_i <= 1'b1;
                         user_interrupt_i    <= 1'b0;
                         n_read_i            <= 1'b1;
                        end
    `rd_status_byte : begin
                        header_interrupt_i  <= 1'b0;
                        trailer_interrupt_i <= 1'b0;
                        user_interrupt_i    <= 1'b1;
                        if ( status_byte_ok == 1'b1)
                         n_read_i <= 1'b1;
                        else
                         n_read_i            <= 1'b0;
                      end
    `userInterrupt  : begin
                        header_interrupt_i  <= 1'b0;
                        trailer_interrupt_i <= 1'b0;
                        user_interrupt_i    <= 1'b1;
                        n_read_i            <= 1'b1;
                      end
    default : begin
               header_interrupt_i  <= 1'b0;
               trailer_interrupt_i <= 1'b0;
               user_interrupt_i    <= 1'b0;
               n_read_i            <= 1'b1;
              end
   endcase
end
 //-----------------------------------------------------------------------//
 //-----------------------------------------------------------------------//
always @(posedge clk or negedge n_reset)
 begin : output_reg
  if( n_reset == 1'b0)
   begin
     header_interrupt  <= 1'b0;
     trailer_interrupt <= 1'b0;
     user_interrupt    <= 1'b0;
     n_read            <= 1'b1;
  end else
    begin
     header_interrupt  <= header_interrupt_i;
     trailer_interrupt <= trailer_interrupt_i;
     user_interrupt    <= user_interrupt_i;
     n_read            <= n_read_i;
   end
end

 //-----------------------------------------------------------------------//
 //-                          synchronisations                           -// 
 //-----------------------------------------------------------------------//

always@(posedge clk or negedge n_reset)
begin
 if( n_reset == 1'b0) 
 begin
  n_read_r  <= 1'b1;
  interrupt_r <= 1'b1;
 end 
 else begin
  n_read_r  <= n_read;
  interrupt_r <= interrupt;
  end
end


 //-----------------------------------------------------------------------//
 //-                          status_byte                                -// 
 //-----------------------------------------------------------------------//

always @(posedge clk or negedge n_reset)
begin
 if(n_reset == 1'b0)
  status_byte <= 8'b00000000;
 else if ( interrupt_presentstate == `headerInterrupt)
  status_byte <= 8'h01;
 else if ( interrupt_presentstate == `trailerInterrupt)
  status_byte <= 8'h02;
 else if ( interrupt_presentstate == `rd_status_byte)
  status_byte <= data;
end

 //-----------------------------------------------------------------------//
 //-                          status_byte_ok                             -// 
 //-----------------------------------------------------------------------//


  always@(posedge clk or negedge n_reset)
  begin
   if(n_reset == 1'b0)
    status_byte_ok_s <= 1'b0;
   else if ( n_read_r == 1'b0 && n_wait == 1'b1)
    status_byte_ok_s <= 1'b1;
   else if ( interrupt_presentstate == `headerInterrupt || interrupt_presentstate == `trailerInterrupt )
     status_byte_ok_s <= 1'b1;
   else if ( interrupt_presentstate == `idle)
     status_byte_ok_s <= 1'b0;
   end

   assign status_byte_ok = status_byte_ok_s | (~n_read_r & n_wait);
 //-----------------------------------------------------------------------//
 //-                          n_sync                                     -// 
 //-----------------------------------------------------------------------//

always@ (n_read or n_read_r)
 begin
  n_sync <= n_read | ~n_read_r;
 end


 //-----------------------------------------------------------------------//
 //-                          FIN                                        -// 
 //-----------------------------------------------------------------------//


 endmodule

