// txunit.v
//-----------------------------------------------------------------------
//-
//- Entity name :TxUnit
//-
//----------------------------------------------------------------------

`timescale 1ns / 100ps
`define idle            5'b00000
`define waitstatusbyte  5'b00001
`define txheader_int    5'b00010
`define precontrol1_int 5'b00011
`define txcontrol1_int  5'b00100
`define precontrol2_int 5'b00101
`define txcontrol2_int  5'b00110
`define prestatusbyte   5'b00111
`define txstatusbyte    5'b01000
`define pretrailer_int  5'b01001
`define txtrailer_int   5'b01010
`define endinterrupt    5'b01011
`define preheader       5'b01100
`define txheader        5'b01101
`define precontrol1     5'b01110
`define txcontrol1      5'b01111
`define precontrol2     5'b10000
`define txcontrol2      5'b10001
`define pre_rd_data     5'b10010
`define rd_data         5'b10011
`define predata         5'b10100
`define tx_data         5'b10101
`define txtrailer       5'b10110
`define endtx           5'b10111

`define HEADER  8'b10101010
`define TRAILER 8'b01010101

module txunit(

// signaux systèmes
  n_reset,
  clk,

// Interface avec l'USB
  TXE,
  WR,
  usb_data,
  en_usb_data,

// Interface avec le périphérique
  n_sync,
  n_read,
  n_wait,
  data,
  busy,

// Interface avec les autres modules
  
  runtx,
  Ndata,
  interrupt,
  subadd,
  status_byte,
  status_byte_ok,
  busyrx,
  busytx,
  endtx,
  endinterrupt,
  single_data_bus
  );



  input n_reset;
  input clk;

  input TXE;
  output  WR;
  output [7:0] usb_data;
  output en_usb_data;

  output n_sync;
  output n_read;
  input n_wait;
  input [7:0] data;
  output busy;
  
  input  runtx;
  input [15:0] Ndata;
  input interrupt;
  input [6:0] subadd;
  input [7:0] status_byte;
  input status_byte_ok;
  input busyrx;
  output busytx;
  output endtx;
  output endinterrupt;
  input single_data_bus;


// Sorties

  reg WR;
  reg [7:0] usb_data;
  reg en_usb_data;
  //reg n_sync;
  wire n_sync;
  reg n_read;
  reg busy;
  reg busytx;
  reg endtx;
  reg endinterrupt;


// signaus internes

  reg txe_latch;
  reg [4:0] tx_presentstate, tx_nextstate;
  reg TXE_r;
  reg WR_r;
  reg n_read_r;
  reg [16:0] cptNdata;
  reg [7:0] data_latch;
  reg rd_data_ok_s;
  wire rd_data_ok;
  reg end_data;
  wire [7:0]NdataLsb;
  

  reg n_read_i;
  reg busytx_i;
  reg WR_i;
  reg [7:0]usb_data_i;
  reg endtx_i;
  reg endinterrupt_i;
  reg busy_i;
  reg first_nread;
  reg busy_r;


 //-----------------------------------------------------------------------//
 //-                              txe_latch                              -// 
 //-----------------------------------------------------------------------//

  
  always @(posedge clk or negedge n_reset)
  begin
   if( n_reset == 1'b0)
    txe_latch <= 1'b0;
   else if ( TXE == 1'b0 && TXE_r == 1'b1) 
    txe_latch <= 1'b1;
   else if ( WR == 1'b1 && WR_r == 1'b0)
    txe_latch <= 1'b0;
  end

 //-----------------------------------------------------------------------//
 //-                              sync                                   -// 
 //-----------------------------------------------------------------------//
  
  always @(posedge clk or negedge n_reset)
   begin
    if ( n_reset == 1'b0)
     begin
      TXE_r     <= 1'b0;
      WR_r      <= 1'b0;
      n_read_r  <= 1'b1;
      busy_r    <= 1'b0;
     end
    else
      begin
       TXE_r     <= TXE;
       WR_r      <= WR;
       n_read_r  <= n_read;
       busy_r    <= busy;
       end
    end

//-----------------------------------------------------------------------//
//-                        rd_data_ok                                      -// 
//-----------------------------------------------------------------------//

  always@(posedge clk or negedge n_reset)
  begin
   if(n_reset == 1'b0)
    rd_data_ok_s <= 1'b0;
   else if ( n_read_r == 1'b0 && n_wait == 1'b1)
    rd_data_ok_s <= 1'b1;
   else
    rd_data_ok_s <= 1'b0;
  end

 assign rd_data_ok = rd_data_ok_s | (~n_read_r & n_wait);
//-----------------------------------------------------------------------//
//-                        data_latch                                   -// 
//-----------------------------------------------------------------------//

always @(posedge clk or negedge n_reset)
 begin
  if ( n_reset == 1'b0)
   data_latch <= 8'b00000000;
  //else if ( tx_presentstate == `rd_data)
  else if ( n_read == 1'b0) 
  data_latch <= data;
 end

//-----------------------------------------------------------------------//
//-                            en_usb_data                              -// 
//-----------------------------------------------------------------------//


always@(WR or single_data_bus or busy or WR_r)
begin
 if ( single_data_bus == 1'b1)
  //en_usb_data <= (WR | WR_r)& ~busy;
  en_usb_data <= (WR | WR_r)& n_read;
 else
  en_usb_data <= WR | WR_r;
end

//-----------------------------------------------------------------------//
//-                              TX FSM                                 -// 
//-----------------------------------------------------------------------//



always @(posedge clk or negedge n_reset)
 begin : register_generation
  if ( n_reset == 1'b0)
    tx_presentstate <= `idle;
  else
    tx_presentstate <= tx_nextstate;
 end


always @(tx_presentstate or TXE or txe_latch or interrupt or busyrx or runtx
          or status_byte_ok or rd_data_ok or end_data)
 begin : nextstate_logic
  case ( tx_presentstate)
   
   `idle : begin
            if ( interrupt == 1'b1 && busyrx == 1'b0) 
                tx_nextstate <= `waitstatusbyte;
            else if ( runtx == 1'b1 && busyrx == 1'b0)
                tx_nextstate <= `txheader;
            else
                tx_nextstate <= `idle;
            end
   `waitstatusbyte : begin
                        if ( status_byte_ok == 1'b1 && TXE == 1'b0) 
                            tx_nextstate <= `txheader_int;
                        else
                            tx_nextstate <= `waitstatusbyte;
                        end

   `txheader_int :  tx_nextstate <= `precontrol1_int;

   `precontrol1_int : begin
                       if ( txe_latch == 1'b1)
                        tx_nextstate <= `txcontrol1_int;
                       else
                        tx_nextstate <= `precontrol1_int;
                      end
                   
   `txcontrol1_int : tx_nextstate <= `precontrol2_int;

   `precontrol2_int : begin
                       if ( txe_latch == 1'b1)
                        tx_nextstate <= `txcontrol2_int;
                       else
                        tx_nextstate <= `precontrol2_int;
                      end

   
   `txcontrol2_int : tx_nextstate <= `prestatusbyte;

   `prestatusbyte : begin
                     if ( txe_latch == 1'b1)
                      tx_nextstate <= `txstatusbyte;
                     else
                      tx_nextstate <= `prestatusbyte;
                    end

   `txstatusbyte : tx_nextstate <= `pretrailer_int;
                    
   `pretrailer_int : begin
                      if ( txe_latch == 1'b1)
                        tx_nextstate <= `txtrailer_int;
                      else
                        tx_nextstate <= `pretrailer_int;
                      end
                     
   `txtrailer_int : tx_nextstate <= `endinterrupt; 

   `endinterrupt : begin
                    if (txe_latch == 1'b1 || TXE == 1'b1)
                      tx_nextstate <= `idle;
                    else
                      tx_nextstate <= `endinterrupt;
                    end

   `preheader : begin
                 if ( TXE == 1'b0)                 
                   tx_nextstate <= `txheader;
                 else
                   tx_nextstate <= `preheader;
                end
   `txheader : tx_nextstate <= `precontrol1;

   `precontrol1 : begin
                     if ( txe_latch == 1'b1)
                      tx_nextstate <= `txcontrol1;
                     else
                      tx_nextstate <= `precontrol1;
                     end
    
   `txcontrol1 : tx_nextstate <= `precontrol2;

   `precontrol2 : begin
                   if ( txe_latch == 1'b1) 
                     tx_nextstate <= `txcontrol2;
                   else
                     tx_nextstate <= `precontrol2; 
                   end
   `txcontrol2 : tx_nextstate <= `pre_rd_data;

   `pre_rd_data : begin
                  if ( txe_latch == 1'b1)
                   tx_nextstate <= `rd_data;
                  else
                   tx_nextstate <= `pre_rd_data;
                 end
     
   `rd_data: begin
              if ( rd_data_ok == 1'b1)
               tx_nextstate <= `tx_data;
              else
               tx_nextstate <= `rd_data;
              end

  `tx_data :  tx_nextstate <= `predata;
                 
   `predata : begin
               if (end_data == 1'b1 && txe_latch == 1'b1)
                tx_nextstate <= `txtrailer;
               else if (txe_latch == 1'b1) 
                tx_nextstate <= `rd_data;
               else
                tx_nextstate <= `predata;
               end



   `txtrailer : tx_nextstate <= `endtx;
   
   `endtx    : begin
                if (runtx == 1'b0 && (txe_latch == 1'b1 || TXE == 1'b1))
                 tx_nextstate <= `idle;
                else
                 tx_nextstate <= `endtx;
                end

     default : tx_nextstate <= `idle;
 endcase
end



//-----------------------------------------------------------------------//
//-                             FSM OUTPUTs                             -// 
//-----------------------------------------------------------------------//

assign NdataLsb = Ndata[7:0];

always @ (tx_nextstate or data_latch or rd_data_ok or status_byte or subadd or NdataLsb or single_data_bus)
 begin : output_logic
  case ( tx_nextstate)
   `idle : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b0;
            WR_i       <= 1'b0;
            usb_data_i <= 8'b00000000;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0;
            busy_i <= 1'b0;
            end
   `waitstatusbyte : begin
            n_read_i   <= 1'b1;
            busytx_i   <= 1'b1;
            WR_i       <= 1'b0;
            usb_data_i <= 8'b00000000;
            endtx_i    <= 1'b0;
            endinterrupt_i <= 1'b0;
            busy_i         <= 1'b0;
                      end

   `txheader_int :  begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b1;
            usb_data_i <= `HEADER;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0;
            busy_i <= 1'b0;
                        end

   `precontrol1_int : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;
            //usb_data_i <= 8'b00000000;
            usb_data_i <= `HEADER;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0;
            busy_i <= 1'b0;
                        end

   `txcontrol1_int : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b1;
            usb_data_i <= 8'b00000000;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0;
            busy_i <= 1'b0;
                        end

   `precontrol2_int : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;            
            usb_data_i <= 8'b00000000;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0;
            busy_i <= 1'b0;           
                        end
   
   `txcontrol2_int : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b1;           
            usb_data_i <= {1'b0,subadd};
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
                        end

   `prestatusbyte : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;         
            //usb_data_i <= 8'b00000000;
            usb_data_i <= {1'b0,subadd};            
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
                        end

   `txstatusbyte : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b1;            
            usb_data_i <= status_byte;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0;
            busy_i <= 1'b0;
                   end
                    
   `pretrailer_int : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;           
            //usb_data_i <= 8'b00000000;
            usb_data_i <= status_byte;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
                        end
                     
   `txtrailer_int : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b1;            
            usb_data_i <= `TRAILER;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
                        end

   `endinterrupt : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;            
            //usb_data_i <= 8'b00000000;
            usb_data_i <= `TRAILER;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b1; 
            busy_i <= 1'b0;
                        end

   `preheader : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;           
            usb_data_i <= 8'b00000000;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0; 
                 end
   `txheader : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b1;            
            usb_data_i <= `HEADER;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
            end

   `precontrol1 : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;            
            //usb_data_i <= 8'b00000000;
            usb_data_i <= `HEADER;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
                   end

   `txcontrol1 : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b1;            
            usb_data_i <= NdataLsb;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
                 end  

   `precontrol2 : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;            
            //usb_data_i <= 8'b00000000;
            usb_data_i <= NdataLsb;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
                  end
   `txcontrol2 : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b1;           
            usb_data_i <= {1'b1,subadd};
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
                  end
   `pre_rd_data : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;           
            //usb_data_i <= 8'b00000000;
            usb_data_i <= {1'b1,subadd};
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
 			busy_i <= 1'b1;          
                     end

   `rd_data: begin
            busytx_i <= 1'b1;
           /* if (single_data_bus == 1'b1)
              WR_i         <= 1'b1;
            else
              WR_i         <= 1'b0;
                      
            usb_data_i <= 8'b00000000;*/
            WR_i     <= 1'b0;
            n_read_i <= 1'b0;
            usb_data_i <= data_latch;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b1;			
            /*if ( rd_data_ok == 1'b1)
             // n_read_i <= 1'b1;
             WR_i         <= 1'b1;
            else
             WR_i         <= 1'b0;
             // n_read_i <= 1'b0;*/
            end

   `tx_data :  begin
            //n_read_i <= 1'b1;
            n_read_i <= 1'b0;
            busytx_i <= 1'b1;
            /*if (single_data_bus == 1'b1)
              WR_i         <= 1'b0;
            else
              WR_i         <= 1'b1;
            //WR_i       <= 1'b1; */
            WR_i        <= 1'b1;          
            usb_data_i <= data_latch;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b1;
            end

   `predata : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;            
            //usb_data_i <= 8'b00000000;
            usb_data_i <= data_latch;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b1;
            end

   `txtrailer : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b1;           
            usb_data_i <= `TRAILER;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0;
            busy_i <= 1'b0;
                 end

   `endtx    : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b1;
            WR_i       <= 1'b0;            
            //usb_data_i <= 8'b00000000;
            usb_data_i <= `TRAILER;
            endtx_i <= 1'b1;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
            end

     default : begin
            n_read_i <= 1'b1;
            busytx_i <= 1'b0;
            WR_i       <= 1'b0;           
            usb_data_i <= 8'b00000000;
            endtx_i <= 1'b0;
            endinterrupt_i <= 1'b0; 
            busy_i <= 1'b0;
            end
 endcase
end



always @(posedge clk or negedge n_reset)
 begin : output_register
  if (n_reset == 1'b0)
   begin
      n_read <= 1'b1;
      busytx <= 1'b0;
      WR       <= 1'b0;
      usb_data <= 8'b00000000;
      endtx <= 1'b0;
      endinterrupt <= 1'b0;
      busy <= 1'b0;
 end else
  begin
      n_read <= n_read_i;
      busytx <= busytx_i;
      WR       <= WR_i ;
      usb_data <= usb_data_i;
      endtx <= endtx_i;
      endinterrupt <= endinterrupt_i;
      busy <= busy_i;
 end
end
  

 //-----------------------------------------------------------------------//
 //-                        cptNdata                                     -// 
 //-----------------------------------------------------------------------//

 always@(posedge clk or negedge n_reset)
  begin
   if( n_reset == 1'b0)
    cptNdata <= 17'h0000;
   else if (n_read == 1'b0 && n_read_r == 1'b1)
    cptNdata <= cptNdata + 1;
   else if ( endtx == 1'b1)
    cptNdata <= 17'h0000;
  end

//-----------------------------------------------------------------------//
//-                        end_data                                     -// 
//-----------------------------------------------------------------------//

 always@(posedge clk or negedge n_reset)
  begin
   if( n_reset == 1'b0)
    end_data <= 1'b0;
   else if ( cptNdata == Ndata + 1) 
     end_data <= 1'b1;
   else 
    end_data <= 1'b0;
  end

 //-----------------------------------------------------------------------//
 //-                        n_sync                                       -// 
 //-----------------------------------------------------------------------//



always @(posedge clk or negedge n_reset)
  begin
   if( n_reset == 1'b0)
    first_nread <= 0;
   else if( busy == 1'b1 && busy_r == 1'b0)
	first_nread <= 1'b1;
   else if (n_read == 1'b0)
    first_nread <= 1'b0;
  end


assign n_sync = (first_nread & ~n_read)? 1'b0 :1'b1;
  
/* always @(tx_presentstate or n_read or n_read_r or cptNdata)
  begin
   if(tx_presentstate == `rd_data && cptNdata == 17'h0000)
    n_sync <= n_read| ~n_read_r;
   else
    n_sync <= 1'b1;
  end
*/

 //-----------------------------------------------------------------------//
 //-                              FIN                                    -// 
 //-----------------------------------------------------------------------//


endmodule
