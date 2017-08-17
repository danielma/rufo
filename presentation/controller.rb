class FundsController<ApplicationController; def index
 @grouped_funds = Fund.includes(:designations).group_by(:admin_grouping)
  end; def create
    @fund = Fund.new
    result = UpsertFund.call(@fund, fund_params.to_h)
    if result.ok?
      redirect_to funds_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_fund;
 @fund = Fund.find(params[:id])



             end



  
def fund_params; params.require(:fund).permit(:name, :description, :color_identifier, :visibility,
:ledger_code, :sms_code,); end
end
