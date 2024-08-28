module clock_divider(
    input wire clk_in,       // 50MHz saat sinyali girişi
    input wire reset,        // Reset sinyali
    output reg clk_out       // 1Hz saat sinyali çıkışı
);

reg [32:0] counter;

always @(posedge clk_in or posedge reset) begin
    if (reset) begin
        counter <= 0;
        clk_out <= 0;
    end else begin
        if (counter == 29999999) begin
            counter <= 0;
            clk_out <= ~clk_out;
        end else begin
            counter <= counter + 1;
        end
    end
end

endmodule
