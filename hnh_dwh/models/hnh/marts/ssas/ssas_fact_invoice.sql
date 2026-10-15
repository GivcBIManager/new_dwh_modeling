{{ hnh_ssas_view('fact_invoice', drop=['invoice_key', 'episode_key', 'submission_channel'], decimals=['gross_amount', 'discount_amount', 'net_amount', 'vat_amount', 'total_amount']) }}
