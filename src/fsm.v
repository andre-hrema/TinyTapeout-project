`default_nettype none
`timescale 1ns/1ns


module fsm #(
    parameter WORD_SIZE = 8,
    parameter NUM_MEM_ELEMENTS = 16,
    parameter RESULT_WIDTH = 2*WORD_SIZE + $clog2(NUM_MEM_ELEMENTS)
)
(
    // Control signals
    input  wire clk,
    input  wire rst,
    input  wire ena,
    input  wire [1:0] ctl,
    input  wire [3:0] debug_selector,

    // Data
    input wire [WORD_SIZE-1:0] data_in,
    output reg [WORD_SIZE-1:0] data_out,

    // Control
    output reg [1:0] status
);

localparam NUM_MEM_BANKS = 4;

typedef enum logic [1:0] {
    IDLE  = 2'b00,
    WORK  = 2'b01
} state_t;

typedef enum logic [1:0] {
    CTL_IDLE         = 2'b00,
    CTL_WORK         = 2'b01,
    CTL_READ_RESULT  = 2'b11
} ctl_input_t;

typedef enum logic [1:0] {
    MEM_IDLE  =  2'b00,
    MEM_STORE =  2'b01,
    MEM_LOAD  =  2'b10,
    MEM_CLEAR =  2'b11
} mem_ctl_t;

typedef enum logic [1:0] {
    DPE_IDLE               = 2'b00,
    DPE_IN_PROGRESS        = 2'b01,
    DPE_RESULT_AVAILABLE   = 2'b10,
    DPE_INTERNAL_ERROR     = 2'b11
} dpe_status_t;

typedef enum logic [2:0] {
    MEM_A           = 3'b000,
    MEM_B           = 3'b001,
    MEM_C           = 3'b010,
    MEM_D           = 3'b011,
    MAC             = 3'b100,
    FSM             = 3'b101,
    EXEC_ONE_CYCLE  = 3'b110, // operate the MAC for one cycle and pause
    EXEC_CURRENT    = 3'b111  // calculate the current dot product until the end and pause
} debug_sel_t;

state_t state;
reg [1:0] store_memory;
reg [1:0] calc_memory;


logic [WORD_SIZE-1:0] mem_in[3:0];
logic [1:0] mem_ctl[3:0];
logic [WORD_SIZE-1:0] mem_out[3:0];

reg [$clog2(NUM_MEM_ELEMENTS*2):0] mem_load_counter[1:0];
wire [$clog2(NUM_MEM_ELEMENTS*2):0] mem_load_counter_0;
wire [$clog2(NUM_MEM_ELEMENTS*2):0] mem_load_counter_1;


/* The banks will intercalate between data storage and MAC feeder
    Maybe, it will consume too much area, the alternative is to change the storage to a shift register model.
*/
genvar i;
generate
  for (i = 0; i < NUM_MEM_BANKS; i = i + 1) begin : banks
    memory_bank mem_bank_inst (
      .data_in       (mem_in[i]),
      .ctl           (mem_ctl[i]),
      .clk           (clk),
      .rst           (rst),
      .memory_content(mem_out[i])
    );
  end
endgenerate

reg mult_acc_input_valid;
//reg [WORD_SIZE-1:0] mult_acc_input[1:0];
logic [WORD_SIZE-1:0] mult_acc_input[1:0];
reg [RESULT_WIDTH-1:0] result;

// aliases para facilitar o dump (VCD/GTKWave costuma não mostrar arrays desempacotados)
wire [WORD_SIZE-1:0] mult_acc_input_0 = mult_acc_input[0];
wire [WORD_SIZE-1:0] mult_acc_input_1 = mult_acc_input[1];
wire [2*WORD_SIZE-1:0] mult_acc_input_packed = {mult_acc_input[1], mult_acc_input[0]};

reg run_mac;
reg [$clog2(NUM_MEM_ELEMENTS*2):0] mac_counter;
reg [$clog2(NUM_MEM_ELEMENTS):0]  mem_address_counter;

wire [RESULT_WIDTH-1:0] mac_result;
wire done;

mac mult_acc(
    .mod_input(mult_acc_input_packed),
    .input_valid(mult_acc_input_valid),
    .result(mac_result),
    .done(done),
    .clk(clk),
    .rst(rst)
);

always_ff @(posedge clk) begin

    if (rst) begin
        state <= IDLE;
        run_mac <= 0;
        store_memory <= 2'b00;
        calc_memory <= 2'b00;

        mac_counter <= 0;
        mem_address_counter <= 0;
        mem_load_counter[0] <= 0;
        mem_load_counter[1] <= 0;

        mult_acc_input_valid <= 0;
        result <= 0;
        status <= DPE_IDLE;
        data_out <= 0;

        for (integer i = 0; i < NUM_MEM_BANKS; i = i + 1) begin
            mem_ctl[i] <= MEM_IDLE;
        end

    end else begin
        case(ctl)
            CTL_IDLE:
            begin
                state <= IDLE;
            end

            CTL_WORK:
            begin
                state <= WORK;
            end

            // The result is read, but the previous state is not changed,
            // so the storage and calculation keep working in the background
            CTL_READ_RESULT:
            begin
                data_out <= result[RESULT_WIDTH-1:RESULT_WIDTH-WORD_SIZE];
                result <= result << WORD_SIZE;
            end
        endcase

        case(state)
            IDLE:
            begin
                // do nothing, wait for ctl to change
                
            end

            WORK:
            begin
                // It is used when all registers were provided and the MAC can start calulating the dot product
                // In the next clock cycle, info will be stored in the other pair of memory banks.
                if(ctl == CTL_IDLE) begin
                    run_mac <= 1;
                    store_memory <= {~store_memory[1], 1'b0};
                    calc_memory <= {store_memory[1], 1'b0};
                    
                    mem_in[{store_memory[1], 1'b0}] <= mem_address_counter;
                    mem_in[{store_memory[1], 1'b1}] <= mem_address_counter;
                    mem_ctl[{store_memory[1], 1'b0}] <= MEM_LOAD;
                    mem_ctl[{store_memory[1], 1'b1}] <= MEM_LOAD;
                    mem_address_counter <= mem_address_counter + 2'b01;

                end else begin
                    mem_in[store_memory] <= data_in;
                    mem_ctl[store_memory] <= MEM_STORE;
                    mem_ctl[{store_memory[1], ~store_memory[0]}] <= MEM_IDLE;
                    mem_load_counter[store_memory[1]] <= mem_load_counter[store_memory[1]] + 1'b1;

                    store_memory <= {store_memory[1], ~store_memory[0]};
                end
            end

        endcase

        // start dot product calculation
        if(run_mac) begin
            // Check if all items were read from memory, if so, stop feeding the MAC and reset the counter
            if(mac_counter == mem_load_counter[calc_memory[1]]) begin
                run_mac <= 0;
                run_mac <= 0;
                mult_acc_input_valid <= 0;
                mac_counter <= 0;
                mem_address_counter <= 0;
                mem_load_counter[calc_memory[1]] <= 0;
                mem_ctl[{calc_memory[1], 1'b0}] <= MEM_CLEAR;
            // Check if mac_counter reached the maximum number of elements to be read, if so, an error state is triggered
            end else if(mem_address_counter == NUM_MEM_ELEMENTS) begin
                run_mac <= 0;
                run_mac <= 0;
                mult_acc_input_valid <= 0;
                mac_counter <= 0;
                mem_address_counter <= 0;
                mem_load_counter[calc_memory[1]] <= 0;
                mem_ctl[{calc_memory[1], 1'b0}] <= MEM_CLEAR;
                status <= DPE_INTERNAL_ERROR;
            // feed the calculator
            end else begin
                // signal to the module that valid inputs are fed
                mult_acc_input_valid <= 1;

                mem_in[{calc_memory[1], 1'b0}] <= mem_address_counter;
                mem_in[{calc_memory[1], 1'b1}] <= mem_address_counter;
                mem_ctl[{calc_memory[1], 1'b0}] <= MEM_LOAD;
                mem_ctl[{calc_memory[1], 1'b1}] <= MEM_LOAD;


                mac_counter <= mac_counter + 2'b10;
                mem_address_counter <= mem_address_counter + 2'b01;

                status <= DPE_IN_PROGRESS;
            end
        end

        // is dot product done?
        if(done && ctl != CTL_READ_RESULT) begin
            result <= mac_result;
            status <= DPE_RESULT_AVAILABLE;
        end

    end

end
    assign mult_acc_input[0] = mem_out[{calc_memory[1], 1'b0}];
    assign mult_acc_input[1] = mem_out[{calc_memory[1], 1'b1}];

    assign mem_load_counter_0 = mem_load_counter[0];
    assign mem_load_counter_1 = mem_load_counter[1];

endmodule