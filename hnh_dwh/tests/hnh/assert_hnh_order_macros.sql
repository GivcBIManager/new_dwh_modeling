-- Order rules (spec section 5). Each branch returns a row only when a rule is wrong.
select 'order line status wrong' as failure
where {{ hnh_order_line_status("'D'") }} != 'Delivered'
   or {{ hnh_order_line_status("'R'") }} != 'Ordered'
   or {{ hnh_order_line_status("'O'") }} != 'Ordered'
   or {{ hnh_order_line_status("'C'") }} != 'Cancelled'
   or {{ hnh_order_line_status("'P'") }} != 'Not applicable'
   or {{ hnh_order_line_status("'Q'") }} != 'Not applicable'
   or {{ hnh_order_line_status("'X'") }} != 'Not applicable'
   or {{ hnh_order_line_status("'A'") }} != 'Unknown'
   or {{ hnh_order_line_status("cast(null as Nullable(String))") }} != 'Unknown'

union all
select 'order category wrong'
where {{ hnh_order_category("'PK'") }} != 'Package'
   or {{ hnh_order_category("'LAB'") }} != 'Lab'
   or {{ hnh_order_category("'RAD'") }} != 'Radiology'
   or {{ hnh_order_category("'CON'") }} != 'Consultation'
   or {{ hnh_order_category("'PH'") }} != 'Pharmacy'
   or {{ hnh_order_category("'MLK'") }} != 'Pharmacy'
   or {{ hnh_order_category("'SUR'") }} != 'Others'
   or {{ hnh_order_category("cast(null as Nullable(String))") }} != 'Others'

union all
select 'fulfilment status wrong'
where {{ hnh_order_fulfilment_status("'Cancelled'", "toUInt8(1)", "toUInt8(0)", "toUInt8(0)") }} != 'Cancelled'
   or {{ hnh_order_fulfilment_status("'Not applicable'", "toUInt8(1)", "toUInt8(0)", "toUInt8(0)") }} != 'Not applicable'
   or {{ hnh_order_fulfilment_status("'Unknown'", "toUInt8(0)", "toUInt8(0)", "toUInt8(0)") }} != 'Not applicable'
   or {{ hnh_order_fulfilment_status("'Ordered'", "toUInt8(1)", "toUInt8(1)", "toUInt8(1)") }} != 'Delivered'
   or {{ hnh_order_fulfilment_status("'Ordered'", "toUInt8(0)", "toUInt8(1)", "toUInt8(1)") }} != 'Delivered by alternative'
   or {{ hnh_order_fulfilment_status("'Ordered'", "toUInt8(0)", "toUInt8(0)", "toUInt8(1)") }} != 'Delivered by substitute'
   or {{ hnh_order_fulfilment_status("'Delivered'", "toUInt8(0)", "toUInt8(0)", "toUInt8(0)") }} != 'Undelivered'
