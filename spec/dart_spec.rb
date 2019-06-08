RSpec.describe Dart do
  it "has a version number" do
    expect(Dart::VERSION).not_to be nil
  end

  it 'can parse json' do
    expect(Dart.from_json('{}').get_type).to be :object
  end

  it "does something useful" do
    #expect(false).to eq(true)
  end
end
