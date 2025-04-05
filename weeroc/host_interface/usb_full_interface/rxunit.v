// RxUnit.v

//-----------------------------------------------------------------------
//-
//- Entity name :RxUnit
//-
//-----------------------------------------------------------------------
`timescale 1ns / 100ps
`define idle 4'b0000
`define rd_header 4'b0001
`define check_header 4'b0010
`define error_header 4'b0011
`define rd_controle1 4'b0100
`define load_ndata_lsb 4'b0101
`define rd_controle2 4'b0110
`define check_controle2 4'b0111
`define rd_data1 4'b1000
`define wr_data1 4'b1001
`define rd_data2 4'b1010
`define load_ndata_msb 4'b1011
`define rd_trailer 4'b1100
`define check_trailer 4'b1101

`define error_trailer 4'b1110
`define runtx 4'b1111

`define HEADER 8'b10101010
`define TRAILER 8'b01010101


module rxunit (

// Signaux Système 
    n_reset,
    clk,
// Interface avec l'hôte
    rxf,
    rd,
    usb_data,
// Interface Périphérique
    data,
    subadd,
    n_write,
    n_sync,
    n_wait,
    busy,
// interface avec interruptunit
    interrupt,
// Interface avec les autres modules
    header_error,
    header_ok,
    trailer_error,
    busyrx,
    busytx,
    readrequestbusy,
    rxf_latch,
    endtx,
    NdataLsb,
    NdataMsb,
    runtx,
// debug
	end_write,
	end_data);


    input  n_reset;
    input  clk;
    input  rxf;
    output rd;
    input  [7:0] usb_data;
    output [7:0] data;
    output [6:0] subadd;
    output n_write;
    output n_sync;
    input  n_wait;
    output busy;
    input  interrupt;
    output header_error;
    output header_ok;
    output trailer_error;
    output busyrx;
    input  busytx;
    input  readrequestbusy;
    output rxf_latch;
    input  endtx;
    output [7:0] NdataMsb;
    output [7:0] NdataLsb;
    output runtx;
	output end_write;
	output end_data;
    
    // sorties

    reg rd;
    reg busyrx;
    reg header_error;
    reg header_ok;
    reg trailer_error;
    reg runtx;
    reg n_write;
    //reg n_sync;
    wire n_sync;
    reg busy;
    reg [7:0] data;
    reg [6:0] subadd;
    reg [7:0] NdataLsb;
    reg [7:0] NdataMsb;
    reg rxf_latch;



    // signaux internes
    reg [3:0] rx_presentstate,rx_nextstate;
    reg rxf_r;
    reg [1:0] cptdatavalid;
    reg datavalid;
    reg read_write;
    reg end_data;
    reg end_write_r1;
    reg end_write_r2;
    reg end_write_s;
	wire end_write;
    reg trailer_ok;
    reg [7:0] data_latch;
    reg [8:0] cptNdata;
    reg n_write_r1;
    reg  rd_i;
    reg busyrx_i;
    reg runtx_i;
    reg n_write_i;
    reg busy_i; 
    reg busy_r;
    reg first_nwrite;


 //-----------------------------------------------------------------------//
 //-                        FSM RX STATE                                 -// 
 //-----------------------------------------------------------------------//
 

 always @(posedge clk or negedge n_reset)
  begin
   if( n_reset == 1'b0)
    rx_presentstate  <= `idle;
   else rx_presentstate <= rx_nextstate;
  end

  always @(rx_presentstate or rxf_latch or rxf or busytx or readrequestbusy or interrupt or datavalid 
        or header_ok or header_error or read_write or end_write_r1 or end_data or trailer_ok or trailer_error or endtx)
  begin: rx_nextstate_logic
   case (rx_presentstate) 
    `idle : begin
                    if ( rxf_latch == 1'b1 && busytx == 1'b0 && readrequestbusy == 1'b0 &&                  
                        interrupt == 1'b0 ) 
                        rx_nextstate <= `rd_header;
                    else
                        rx_nextstate <= `idle;
                    end
     

    `rd_header : begin
                    if( datavalid == 1'b1) 
                        rx_nextstate <= `check_header;
                    else
                        rx_nextstate <= `rd_header;
                    end

    `check_header : begin
                    if ( header_ok == 1'b1 && rxf_latch == 1'b1)
                        rx_nextstate <= `rd_controle1;
                    else if ( header_error == 1'b1)
                        rx_nextstate <= `error_header;
                    else
                        rx_nextstate <= `check_header;
                    end 

    `error_header : rx_nextstate <= `idle;

    `rd_controle1 : begin
                    if( datavalid == 1'b1)
                        rx_nextstate <= `load_ndata_lsb;
                    else 
                        rx_nextstate <= `rd_controle1;
                    end


    `load_ndata_lsb : begin
                    if ( rxf_latch == 1'b1) 
                        rx_nextstate <= `rd_controle2;
                    else
                        rx_nextstate <= `load_ndata_lsb;
                    end

    `rd_controle2 : begin
                    if ( datavalid == 1'b1)
                        rx_nextstate <= `check_controle2;
                    else
                        rx_nextstate <= `rd_controle2;
                    end

    `check_controle2 : begin
                    if ( read_write == 1'b0 && rxf_latch == 1'b1)
                        rx_nextstate <= `rd_data1;
                    else if ( read_write == 1'b1 && rxf_latch == 1'b1)
                        rx_nextstate <= `rd_data2;
                    else
                        rx_nextstate <= `check_controle2;
                    end

    `rd_data1 : begin
                    if ( datavalid == 1'b1)
                        rx_nextstate <= `wr_data1;
                    else
                        rx_nextstate <= `rd_data1;
                    end

    `wr_data1 : begin
                    if ( end_write_r1 == 1'b1 && end_data == 1'b1 && rxf_latch == 1'b1)
                     rx_nextstate <= `rd_trailer;
                    else if ( end_write_r1 == 1'b1 && rxf_latch == 1'b1) 
                     rx_nextstate <= `rd_data1;
                    else
                     rx_nextstate <= `wr_data1;
                    end

    `rd_data2 : begin
                    if( datavalid == 1'b1) 
                       rx_nextstate <= `load_ndata_msb;
                    else
                       rx_nextstate <= `rd_data2;
                    end

    `load_ndata_msb : begin
                    if ( rxf_latch == 1'b1)
                       rx_nextstate <= `rd_trailer;
                    else
                       rx_nextstate <= `load_ndata_msb;
                    end


    `rd_trailer : begin
                  if ( datavalid == 1'b1) 
                      rx_nextstate <= `check_trailer;
                  else
                      rx_nextstate <= `rd_trailer;
                  end

    `check_trailer : begin
                 
                    if ( trailer_ok == 1'b1 && read_write == 1'b1 && (rxf == 1'b1 || rxf_latch == 1'b1))
                      rx_nextstate <= `runtx;
                    else if (trailer_ok == 1'b1 && read_write == 1'b0)
                      rx_nextstate <= `idle;
                    else if ( trailer_error == 1'b1)
                      rx_nextstate <= `error_trailer;
                    else
                      rx_nextstate <= `check_trailer;
                    end



   `error_trailer : rx_nextstate <= `idle;

    `runtx : begin
             if ( endtx == 1'b1)
              rx_nextstate <= `idle;
             else
              rx_nextstate <= `runtx;
             end
      default: rx_nextstate <= `idle;
   endcase
end

 //-----------------------------------------------------------------------//
 //-                        FSM OUTPUT                                   -// 
 //-----------------------------------------------------------------------//
 
always @(rx_nextstate or end_write) 
begin : output_logic
 case ( rx_nextstate)
    
    `idle : begin
                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b0;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    `rd_header : begin
                    rd_i      <= 1'b0;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    `check_header : begin
                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    `error_header : begin
                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end

    `rd_controle1 : begin
                    rd_i      <= 1'b0;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    `load_ndata_lsb : begin
                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    `rd_controle2 : begin
                    rd_i      <= 1'b0;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    `check_controle2 : begin
                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    `rd_data1 : begin
                    rd_i      <= 1'b0;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b1;
                    end
    `wr_data1 : begin
                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    busy_i    <= 1'b1;
                    if ( end_write == 1'b1)
                       n_write_i <= 1'b1;
                    else n_write_i <= 1'b0;
				end
                   
    `rd_data2 : begin
                    rd_i      <= 1'b0;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    `load_ndata_msb : begin
                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    `rd_trailer : begin
                    rd_i      <= 1'b0;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    `check_trailer : begin
                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end

    `error_trailer : begin

                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b1;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                     end
    `runtx : begin
                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b0;
                    runtx_i   <= 1'b1;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end

     default : begin
                    rd_i      <= 1'b1;
                    busyrx_i  <= 1'b0;
                    runtx_i   <= 1'b0;
                    n_write_i <= 1'b1;
                    busy_i    <= 1'b0;
                    end
    endcase
end

// OUTPUT REG


always @(posedge clk or negedge n_reset)
begin
 if( n_reset == 1'b0)
     begin
       rd      <= 1'b1;
       busyrx  <= 1'b0;
       runtx   <= 1'b0;
       n_write <= 1'b1;
       busy    <= 1'b0;
       busy_r  <= 1'b0;
  end
else
  begin
       rd      <= rd_i;
       busyrx  <= busyrx_i;
       runtx   <= runtx_i;
       n_write <= n_write_i;
       busy    <= busy_i;
       busy_r  <= busy;     
  end
end
  
 //-----------------------------------------------------------------------//
 //-                      Signaux de contrôle de la FSM                  -// 
 //-----------------------------------------------------------------------//
 

 //-----------------------------------------------------------------------//
 //-                       synchronisation des signaux                   -// 
 //-----------------------------------------------------------------------//

 
  always @(posedge clk or negedge n_reset)
  begin : synchronisation
    if ( n_reset == 1'b0) 
     begin
      rxf_r       <= 1'b1;
      n_write_r1  <= 1'b1;
      end_write_r1 <= 1'b0;
      end_write_r2 <= 1'b0;
     end
    else
      begin
       rxf_r       <= rxf;
       n_write_r1  <= n_write;
       end_write_r1 <= end_write;
       end_write_r2 <= end_write_r1;
      end
  end

 //--------------------------------------------------------------n---------//
 //-                        RXF LATCH                                    -// 
 //-----------------------------------------------------------------------//
 
  always @(posedge clk or negedge n_reset)
  begin : rxflatch
    if ( n_reset == 1'b0) 
         rxf_latch <= 1'b0; 
    else if ( rxf_r == 1'b1 && rxf == 1'b0) rxf_latch <= 1'b1;
    else if (datavalid == 1'b1 || rxf == 1'b1) rxf_latch <= 1'b0;
  end
 
 
 //-----------------------------------------------------------------------//
 //-           DATA VALID (pour que RD dure min 50 ns)                  -// 
 //-----------------------------------------------------------------------//
 
 always @(posedge clk or negedge n_reset)
  begin
    if ( n_reset == 1'b0) 
      cptdatavalid <= 2'b00;
    else if (rd == 1'b0)
     begin
       if(cptdatavalid != 2'b01) 
        cptdatavalid <= cptdatavalid + 1;
     end
    else  
      cptdatavalid <= 2'b00;
  end

always @(posedge clk or negedge n_reset)
 begin
 if (n_reset == 1'b0)
  datavalid <= 1'b0;
 else if (rd== 1'b0)
  begin
      if ( cptdatavalid == 2'b01) datavalid <= 1'b1;
      else datavalid <= 1'b0;
  end
 else
  datavalid <= 1'b0; 
end

 //-----------------------------------------------------------------------//
 //-                    DATA_LATCH                                       -// 
 //-----------------------------------------------------------------------//

 always @(posedge clk or negedge n_reset)
 begin : datalatch
    if ( n_reset == 1'b0)
      data_latch <= 8'b00000000;
    else if (datavalid == 1'b1 && rd == 1'b0)
      data_latch <= usb_data;
  end

 //-----------------------------------------------------------------------//
 //-                    Header_error, Header_ok                          -// 
 //-----------------------------------------------------------------------//

 always@(posedge clk or negedge n_reset)
  begin
   if(n_reset == 1'b0)
    begin
     header_error <= 1'b0;
     header_ok    <= 1'b0;
	end
   else if ( rx_presentstate == `check_header)
   begin
    if ( data_latch == `HEADER)
      header_ok <= 1'b1;
    else
      header_error <= 1'b1;
    end
   else begin
      header_ok <= 1'b0;
      header_error <= 1'b0;
   end
 end
 
 //-----------------------------------------------------------------------//
 //-                    Trailer_error, Trailer_ok                        -// 
 //-----------------------------------------------------------------------//
   
always@(posedge clk or negedge n_reset)
  begin
   if(n_reset == 1'b0) 
    begin
     trailer_error <= 1'b0;
     trailer_ok    <= 1'b0;
    end
   else if ( rx_presentstate == `check_trailer)
    begin
     if ( data_latch == `TRAILER)
       trailer_ok <= 1'b1;
     else
       trailer_error <= 1'b1;
    end
   else
     begin
      trailer_ok <= 1'b0;
      trailer_error <= 1'b0;
     end
 end


 //-----------------------------------------------------------------------//
 //-                        subadd et read_write                        -// 
 //-----------------------------------------------------------------------//

always@(posedge clk or negedge n_reset)
  begin
   if(n_reset == 1'b0)
    begin
     subadd <= 7'b0000000;
     read_write <= 1'b1;
    end
   else if ( rx_presentstate == `check_controle2)
    begin
     subadd     <= data_latch[6:0];
     read_write <= data_latch[7];
    end
 end


 //-----------------------------------------------------------------------//
 //-                        end_write                                    -// 
 //-----------------------------------------------------------------------//


always@(posedge clk or negedge n_reset)
 begin
  if ( n_reset == 1'b0)
    end_write_s <= 1'b0;
  else if (rx_presentstate == `wr_data1)
   begin
    if (n_write_r1 == 1'b0 && n_wait == 1'b1) 
     end_write_s <= 1'b1;
   end
  else
    end_write_s <= 1'b0;      
 end

assign end_write = end_write_s | (~n_write_r1 & n_wait);


 //-----------------------------------------------------------------------//
 //-                        cptNdata                                     -// 
 //-----------------------------------------------------------------------//

 always@(posedge clk or negedge n_reset)
  begin
   if( n_reset == 1'b0)
    cptNdata <= 9'h00;
   else if ( cptNdata == NdataLsb + 1) 
      cptNdata <= 9'h00;
  // else if (n_write == 1'b1 && n_write_r1 == 1'b0)
   else if (n_write == 1'b0 && n_write_r1 == 1'b1) // front descendant de n_write
    cptNdata <= cptNdata + 1;
  end


 //-----------------------------------------------------------------------//
 //-                        end_data                                     -// 
 //-----------------------------------------------------------------------//

always@(posedge clk or negedge n_reset)
  begin
   if ( n_reset == 1'b0)
    end_data <= 1'b0;
   else if ( rx_presentstate == `wr_data1) 
    begin
     if ( cptNdata == NdataLsb + 1)
      end_data <= 1'b1;
    end
   else
     end_data <= 1'b0;
  end
 //-----------------------------------------------------------------------//
 //-                    AUTRES SORTIES du module RXUNIT                  -// 
 //-----------------------------------------------------------------------//


 //-----------------------------------------------------------------------//
 //-                        Ndata                                        -// 
 //-----------------------------------------------------------------------//

always@(posedge clk or negedge n_reset)
 begin
   if(n_reset == 1'b0)
     NdataMsb <= 8'b00000000;
   else if ( rx_presentstate == `load_ndata_msb)
     NdataMsb <= data_latch;
  end

always@(posedge clk or negedge n_reset)
 begin
   if(n_reset == 1'b0)
     NdataLsb <= 8'b00000000;
   else if ( rx_presentstate == `load_ndata_lsb)
    NdataLsb <= data_latch;
 end


 //-----------------------------------------------------------------------//
 //-                        data                                         -// 
 //-----------------------------------------------------------------------//

  always @(rx_presentstate or end_write_r1 or data_latch or end_write_r2)
   begin
    if ( rx_presentstate == `wr_data1 && end_write_r2 == 1'b0)
        data <= data_latch;
    else
        data <= 8'b00000000;
   end
 

 //-----------------------------------------------------------------------//
 //-                        n_sync                                       -// 
 //-----------------------------------------------------------------------//


always @(posedge clk or negedge n_reset)
  begin
   if( n_reset == 1'b0)
    first_nwrite <= 0;
   else if( busy == 1'b1 && busy_r == 1'b0)
	first_nwrite <= 1'b1;
   else if (n_write == 1'b0)
    first_nwrite <= 1'b0;
  end


assign n_sync = (first_nwrite & ~n_write)? 1'b0 :1'b1;

/*
 always @(rx_presentstate or n_write or n_write_r1 or cptNdata)
  begin
   if(rx_presentstate == `wr_data1 && cptNdata == 9'h00)
    n_sync <= n_write| ~n_write_r1;
   else
    n_sync <= 1'b1;
  end
*/
 
//------------------------------------------------------------------------//
//-                       FIN                                           --// 
//------------------------------------------------------------------------//

endmodule
        
    




