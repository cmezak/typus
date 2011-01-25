require "spec_helper"

describe 'Typus' do

  it "has and admin_title" do
    Typus.admin_title.should == 'Typus'
  end

end
