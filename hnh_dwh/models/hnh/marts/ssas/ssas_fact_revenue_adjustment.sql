{{ hnh_ssas_view('fact_revenue_adjustment', drop=['adjustment_key', 'episode_key', 'doc_id'], decimals=['adjustment_amount', 'base_invoice_net_amount']) }}
