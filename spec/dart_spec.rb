RSpec.describe Dart do
  it 'has a version number' do
    expect(Dart::VERSION).not_to be nil
  end

  it 'can parse json' do
    expect(Dart.from_json('{}').get_type).to be :object
  end

  it 'can reconstruct objects' do
    expect(Dart.from_bytes(Dart.from_json('{}').get_bytes).get_type).to be :object
  end
end

RSpec.describe Dart::Object do
  it 'starts out empty' do
    expect(subject.empty?).to be true
  end

  it 'inserts strings' do
    subject['hello'] = 'world'
    expect(subject['hello']).to eq 'world'
  end
end
