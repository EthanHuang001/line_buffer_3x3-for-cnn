There is a submodule named "register" inside that you need to instantiate yourself. You can define the bit width yourself, select a depth of 1024, use a single clock, create a read enable port, and output without a register. The ports are as follows:
里面有个子模块名叫register需要你自己去例化。位宽自己定，深度选1024，单时钟，创造一个读使能端口，并且输出不带寄存器。端口如下：
module register (
    clock,
    data,
    rdaddress,
    wraddress,
    wren,
    rden,
    q);

    input	  clock;
    input	[7:0]  data;
    input	[9:0]  rdaddress;
    input	[9:0]  wraddress;
    input	  wren;
    output	[7:0]  q;
    input	  rden;
    
