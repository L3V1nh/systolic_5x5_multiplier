class axi_transaction;
	typedef enum bit {WRITE, READ} operation_t;

	operation_t operation;
	logic [31:0] addr;
	logic [31:0] data;
	int unsigned delay_cycles;

	logic [31:0] read_data;
	logic [1:0] response;

	function new(
		operation_t operation = WRITE,
		logic [31:0] addr = '0,
		logic [31:0] data = '0
	);
		this.operation = operation;
		this.addr = addr;
		this.data = data;
		this.delay_cycles = 0;
		this.read_data = '0;
		this.response = 2'b00;
	endfunction

	function string convert2string();
		if (operation == WRITE) begin
			return $sformatf(
				"WRITE addr=0x%08h data=0x%08h delay=%0d",
				addr, data, delay_cycles
			);
		end

		return $sformatf(
			"READ addr=0x%08h data=0x%08h delay=%0d",
			addr, read_data, delay_cycles
		);
	endfunction
endclass

