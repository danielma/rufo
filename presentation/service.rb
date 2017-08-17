

# empty space up here

class UpsertFund; include Service

def initialize(fund, attributes);             @fund = fund
  @attributes = attributes
end; def call
assign_attributes
if fund.save
update_fund_positions_in_destination_admin_group
success
else
failure("Failed to save")
end
end

private

attr_reader(:fund, :attributes)
def update_fund_positions_in_destination_admin_group
return if fund.default?

fund_ids_in_group = Fund.public_send(fund.admin_grouping).pluck(:id)
Fund.update_positions(fund_ids_in_group)
end
def assign_attributes
admin_grouping_was = fund.admin_grouping
fund.assign_attributes(attributes)
fund.position = -1 if (fund.new_record? || fund.admin_grouping)
end
end
