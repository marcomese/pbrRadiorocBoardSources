// usb_interface.v

//-----------------------------------------------------------------------
//-
//- Entity name : usb_interface
//-
//-----------------------------------------------------------------------


module usb_full_interface_ft2232h_async_fifo_v(

    n_reset, 
    clk, 
    RXF,
    RD,
    TXE,
    WR,
    USB_DATA,
    single_data_bus,
    subadd,
    data,
    n_write,
    n_read,
    n_sync,
    n_wait,
    interrupt,
    read_req,
    busy);

    input n_reset;
    input clk;
    input RXF;
    output RD;
    input TXE;
    output WR;
    inout [7:0] USB_DATA;
    input single_data_bus;
    output [6:0] subadd;
    inout [7:0] data;
    output n_write;
    output n_read;
    output n_sync;
    input n_wait;
    input interrupt;
    input read_req;
    output busy;

 

  // sorties
   
   wire RD;
   wire [7:0] USB_DATA;
   //reg WR;
   wire WR;
   wire [6:0] subadd;
   wire [7:0] data;
   wire n_write;
   wire n_read;
   wire n_sync;
   wire busy;
   wire en_usb_data;
	
	//debug
	
	wire end_write;
	wire end_data;
  // signaux internes
    
    wire rxunit_rxf_latch;
    wire [7:0]usb_data_in;
    wire [7:0] usb_data_out;
    wire [7:0]data_in;
    wire [7:0] data_out;
    wire [6:0]subaddfromrx;
    wire n_syncfromrx;
	wire n_writefromrx;
    wire busyfromrx;
    wire interrupt_torx;
    wire interrupt_totx;
    wire interrupt_toreadreq;
    wire header_error;
    wire header_ok;
    wire trailer_error;
    wire busyrx;
    wire busytx;
    wire busyreadreq;
    wire endtx;
    wire [7:0] NdataLsbfromrx;
    wire [7:0] NdataMsbfromrx;
    wire runtxfromrx;
    wire [7:0]datafromrx;
    wire [7:0] usb_data_fromtx;
    wire n_syncfromtx;
    wire n_readfromtx;
    wire busyfromtx;
    wire runtx;
    wire [6:0]subaddtotx;
    wire [7:0] status_byte;
    wire status_byte_ok;
    wire endinterrupt;
    wire n_readfromreadreq;
    wire [7:0] NdataLsbfromreadreq;
    wire runtxfromreadreq;
    wire n_readfromint;
    wire n_syncfromint;
    wire header_interrupt;
    wire trailer_interrupt;
    wire user_interrupt;
    wire busyrx_toreadreq;
    wire interrupt_latch;
    wire rxf_latch_fromrx;
    wire en_usb_data_fromrx;
    wire en_usb_data_fromtx;
    wire wr_fromtx;
    wire en_data_out;
    wire n_read_s;

    wire rxf_r1;
	reg rxf_r1_2;
    reg rxf_r2;
    reg rxf_latch;
    wire txe_r1;
	reg  txe_r1_2;
    reg  txe_r2;
    reg txe_latch;
    reg interrupt_r1, interrupt_r2;
    reg read_req_r1, read_req_r2;
    reg n_write_r, n_read_r;
    reg [15:0] Ndata;

//-----------------------------------------------------------------------//
//-                       usb_data et data et subadd                    -// 
//-----------------------------------------------------------------------//

always @(posedge clk or negedge n_reset)
begin
if( n_reset == 1'b0) 
	n_write_r <= 1'b1;
else 
	n_write_r <= n_write;
end


always @(negedge clk or negedge n_reset)
begin
if( n_reset == 1'b0)
begin
	n_read_r <= 1'b1;
	//WR <= 1'b0;
end
else 
begin
	n_read_r <= n_read_s;
	//WR <= wr_fromtx;
end
end


//INPUT 

assign usb_data_in = USB_DATA;
assign data_in = (single_data_bus)? USB_DATA : data;

// OUTPUT

assign en_data_out = (~single_data_bus & (~n_write | ~n_write_r))? 1'b1 : 1'b0;

assign data_out = (en_data_out)? datafromrx : 8'bZZZZZZZZ;

assign en_usb_data_fromrx = single_data_bus & (~n_write | ~n_write_r);

assign usb_data_out = ( en_usb_data_fromtx)? usb_data_fromtx : 8'bZZZZZZZZ;

assign usb_data_out = (en_usb_data_fromrx)? datafromrx : 8'bZZZZZZZZ;

assign en_usb_data = en_usb_data_fromtx | en_usb_data_fromrx;

assign USB_DATA = ( en_usb_data)? usb_data_out : 8'bZZZZZZZZ;

assign data = data_out;

assign subadd = (busyreadreq | user_interrupt)? 7'b1111111 : subaddfromrx;

//-----------------------------------------------------------------------//
//-                      n_read, n_write, n_sync, busy                  -// 
//-----------------------------------------------------------------------//

assign n_read_s = n_readfromtx & n_readfromreadreq & n_readfromint;
assign n_read = n_read_s & n_read_r;

assign n_sync = n_syncfromrx & n_syncfromtx & n_syncfromint;
assign n_write = n_writefromrx;
assign busy = busyfromrx | busyfromtx | busyreadreq;

//-----------------------------------------------------------------------//
//-                        RXUNIT INSTANTIATION                         -// 
//-----------------------------------------------------------------------//

rxunit m_rxunit(

    .n_reset(n_reset),
    .clk(clk),
    .rxf(rxf_r2),
    .rd(RD),
    .usb_data(usb_data_in),
    .data(datafromrx),
    .subadd(subaddfromrx),
    .n_write(n_writefromrx),
    .n_sync(n_syncfromrx),
    .n_wait(n_wait),
    .busy(busyfromrx),
    .interrupt(interrupt_torx),
    .header_error(header_error),
    .header_ok(header_ok),
    .trailer_error(trailer_error),
    .busyrx(busyrx),
    .busytx(busytx),
    .readrequestbusy(busyreadreq),
    .rxf_latch(rxf_latch_fromrx),
    .endtx(endtx),
    .NdataLsb(NdataLsbfromrx),
    .NdataMsb(NdataMsbfromrx),
    .runtx(runtxfromrx),
	.end_write(end_write),
	.end_data(end_data)
);


//-----------------------------------------------------------------------//
//-                        signaux pour rxunit                          -// 
//-----------------------------------------------------------------------//

assign interrupt_torx = interrupt_latch;

//-----------------------------------------------------------------------//
//-                       TXUNIT INSTANTIATION                          -// 
//-----------------------------------------------------------------------//

txunit m_txunit(
  .n_reset(n_reset),
  .clk(clk),
  .TXE(txe_r2),
  .WR(WR),
  //.WR(wr_fromtx),
  .usb_data(usb_data_fromtx),
  .en_usb_data(en_usb_data_fromtx),
  .n_sync(n_syncfromtx),
  .n_read(n_readfromtx),
  .n_wait(n_wait),
  .data(data_in),
  .busy(busyfromtx),
  .runtx(runtx),
  .Ndata(Ndata),
  .interrupt(interrupt_totx),
  .subadd(subaddtotx),
  .status_byte(status_byte),
  .status_byte_ok(status_byte_ok),
  .busyrx(busyrx),
  .busytx(busytx),
  .endtx(endtx),
  .endinterrupt(endinterrupt),
  .single_data_bus(single_data_bus)
);

//-----------------------------------------------------------------------//
//-                        signaux pour txunit                          -// 
//-----------------------------------------------------------------------//

assign interrupt_totx = interrupt_latch;

always @ (runtxfromrx or runtxfromreadreq or NdataMsbfromrx or NdataLsbfromrx 
          or NdataLsbfromreadreq)
begin
 if ( runtxfromrx == 1'b1)
  Ndata <= {NdataMsbfromrx, NdataLsbfromrx};
 else if ( runtxfromreadreq == 1'b1)
  Ndata <= {8'h00,NdataLsbfromreadreq};
 else
  Ndata <= 16'h0000;
end


assign subaddtotx = subadd;

assign runtx = runtxfromreadreq | runtxfromrx;
//-----------------------------------------------------------------------//
//-                       READREQ INSTANTIATION                          -// 
//-----------------------------------------------------------------------//

readrequnit m_readrequnit(
    .n_reset(n_reset),    
    .clk(clk),
    .read_req(read_req_r2),
    .n_read(n_readfromreadreq),
    .data(data_in),
    .n_wait(n_wait),
    .interrupt(interrupt_toreadreq),
    .txbusy(busytx_toreadreq),
    .NdataLsb(NdataLsbfromreadreq),
    .runtx(runtxfromreadreq),
    .endtx(endtx),
    .rxbusy(busyrx_toreadreq),
    .busyreadreq(busyreadreq)
);

assign interrupt_toreadreq = interrupt_latch; 
assign busyrx_toreadreq = busyrx | rxf_latch_fromrx;
assign busytx_toreadreq = busytx | runtxfromrx;

//-----------------------------------------------------------------------//
//-                       INTERRUPTUNIT INSTANTIATION                    -// 
//-----------------------------------------------------------------------//

interruptunit m_interruptunit(
      .n_reset(n_reset),
      .clk(clk),
      .interrupt(interrupt_r2),
      .n_read(n_readfromint),
      .n_sync(n_syncfromint),
      .n_wait(n_wait),
      .data(data_in),
      .header_error(header_error),
      .header_ok(header_ok),
      .trailer_error(trailer_error),
      .rxbusy(busyrx),
      .txbusy(busytx),
      .header_interrupt(header_interrupt),
      .trailer_interrupt(trailer_interrupt),
      .status_byte(status_byte),
      .status_byte_ok(status_byte_ok),
      .interrupt_ok(endinterrupt),
      .interrupt_latch_out(interrupt_latch),
      .user_interrupt(user_interrupt)
);


//-----------------------------------------------------------------------//
//-                        signaux pour interruptunit                   -// 
//-----------------------------------------------------------------------//

//-----------------------------------------------------------------------//
//-                        synchronisations                             -// 
//-----------------------------------------------------------------------//

always@(RXF or rxf_r2)
begin
	if(rxf_r2 == 1'b1)
		rxf_latch <= 1'b0;
	else if(RXF == 1'b1)
		rxf_latch <= 1'b1;
end

assign rxf_r1 = rxf_latch | RXF;

	
always@(TXE or txe_r2)
begin
	if(txe_r2 == 1'b1)
		txe_latch <= 1'b0;
	else if(TXE == 1'b1)
		txe_latch <= 1'b1;
end

assign txe_r1 = txe_latch | TXE;
	
always@(posedge clk or negedge n_reset)
begin
 if ( n_reset == 1'b0)
  begin
   rxf_r1_2 <= 1'b1;
   txe_r1_2 <= 1'b0;
   interrupt_r1 <= 1'b1;
   interrupt_r2 <= 1'b1;
   read_req_r1 <= 1'b1;
   read_req_r2 <= 1'b1;
 end
else 
 begin
   rxf_r1_2 <= rxf_r1;
   txe_r1_2 <= txe_r1;
   interrupt_r1 <= interrupt;
   interrupt_r2 <= interrupt_r1;
   read_req_r1 <= read_req;
   read_req_r2 <= read_req_r1;
 end
end


// NEGEDGE re_synchro

always@(negedge clk or negedge n_reset)
begin
if(n_reset == 1'b0)
	begin
		rxf_r2 <= 1'b1;
		txe_r2 <= 1'b0;
	end
else
	begin
		rxf_r2 <= rxf_r1_2;
		txe_r2 <= txe_r1_2;
	end
end
	

//-----------------------------------------------------------------------//
//-                       FIN                                           -// 
//-----------------------------------------------------------------------//


endmodule
