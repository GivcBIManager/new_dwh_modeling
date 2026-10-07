{{ hnh_ssas_view('hnh_fact_ap_payment', drop=['ap_payment_key', 'invoice_payment_id', 'payment_date_key_nn', 'bank_account_id', 'invoice_id'], decimals=['amount']) }}
