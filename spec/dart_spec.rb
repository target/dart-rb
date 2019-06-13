def generate_type_tests(scope, except:)
  (%w{ object array string integer decimal boolean null } - [except]).each do |type|
    scope.eval <<-TEST
    it 'is not a/an #{type}' do
      expect(subject.#{type}?).to be false
      expect(subject.get_type).to_not be :#{type}
    end
    TEST
  end
end

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
  it 'is an object' do
    expect(subject.obj?).to be true
    expect(subject.get_type).to be :object
  end

  # Generate all other type checks.
  generate_type_tests(binding, except: 'object')

  it 'starts out empty' do
    expect(subject.empty?).to be true
  end

  it 'starts out mutable' do
    expect(subject.is_finalized).to be false
    expect { subject.get_bytes }.to raise_error Dart::StateError
  end

  it 'inserts strings' do
    subject['hello'] = 'world'
    expect(subject['hello']).to eq 'world'
  end

  it 'inserts integers' do
    subject['int'] = 5
    expect(subject['int']).to eq 5
  end

  it 'inserts decimals' do
    subject['dcm'] = 5.5
    expect(subject['dcm']).to eq 5.5
  end

  it 'inserts booleans' do
    subject['bool'] = true
    expect(subject['bool']).to eq true
  end

  it 'can report its size' do
    subject['yes'] = 'no'
    subject['stop'] = 'go'
    expect(subject.size).to be 2
    subject['hello'] = 'goodbye'
    expect(subject.size).to be 3
    subject.delete('hello')
    expect(subject.size).to be 2
  end

  it 'is comparable' do
    another = Dart::Object.new
    expect(subject).to eq another
    subject[:hello] = 'goodbye'
    expect(subject).not_to eq another
  end

  it 'is iterable' do
    hsh = {'yes' => 'no', 'stop' => 'go', 'hello' => 'goodbye'}
    hsh.each { |k, v| subject[k] = v }
    subject.each { |k, v| expect(v).to eq hsh.delete(k.unwrap) }
    expect(hsh.empty?).to be true
  end

  it 'caches accessed keys' do
    subject['key'] = 'value'
    value = subject['key']
    expect(subject['key']).to be value
  end
end

RSpec.describe Dart::Integer do
  it 'is an integer' do
    expect(subject.int?).to be true
    expect(subject.get_type).to be :integer
  end

  it 'starts as zero' do
    expect(subject).to eq 0
  end

  it 'can be multiplied' do
    expect(subject * 5).to eq 0
    expect(5 * subject).to eq 0
  end
end

RSpec.describe Dart::Decimal do
  it 'is a decimal' do
    expect(subject.dcm?).to be true
    expect(subject.get_type).to be :decimal
  end

  it 'starts as zero' do
    expect(subject).to eq 0.0
  end

  it 'can be multiplied' do
    expect(subject * 5).to eq 0.0
    expect(5 * subject).to eq 0.0
  end
end
