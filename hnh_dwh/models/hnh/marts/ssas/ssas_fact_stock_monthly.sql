{{ hnh_ssas_view('fact_stock_monthly', drop=['stock_monthly_key', 'month_end'], decimals=['stock_value', 'consumption_cost'], floats=['quantity', 'consumption_quantity']) }}
