require 'byebug'

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

RSpec.describe Dart::Array do
  it 'is an array' do
    expect(subject.arr?).to be true
    expect(subject.get_type).to be :array
  end

  # Generate all other type checks.
  generate_type_tests(binding, except: 'array')

  it 'starts out empty' do
    expect(subject.empty?).to be true
  end

  it 'starts out mutable' do
    expect(subject.is_finalized).to be false
    expect { subject.get_bytes }.to raise_error Dart::StateError
  end

  it 'inserts strings' do
    subject.push('world')
    expect(subject.first).to eq 'world'
  end

  it 'inserts integers' do
    subject.push(5)
    expect(subject.first).to eq 5
  end

  it 'inserts decimals' do
    subject.push(5.5)
    expect(subject.first).to eq 5.5
  end

  it 'inserts booleans' do
    subject.push(true)
    expect(subject.first).to eq true
  end

  it 'can report its size' do
    subject.push('yes', 'no')
    subject.push('stop', 'go')
    expect(subject.size).to be 4
    subject.push('hello')
    expect(subject.size).to be 5
    subject.push('goodbye')
    expect(subject.size).to be 6
    subject.pop
    subject.pop
    expect(subject.size).to be 4
  end

  it 'is comparable' do
    another = Dart::Array.new
    expect(subject).to eq another
    subject[3] = 'goodbye'
    expect(subject).not_to eq another
  end

  it 'is iterable' do
    arr = %w{ yes no stop go hello goodbye }
    arr.each { |v| subject.push(v) }
    subject.reverse_each.with_index { |v, i| expect(v).to eq arr.pop }
    expect(arr.empty?).to be true
  end

  it 'caches accessed keys' do
    subject[0] = 'hello'
    value = subject[0]
    expect(subject[0]).to be value
  end
end

RSpec.describe Dart::Integer do
  it 'is an integer' do
    expect(subject.int?).to be true
    expect(subject.get_type).to be :integer
  end

  it 'starts as zero' do
    expect(subject).to eq 0
    expect(0).to eq subject
  end

  it 'can be multiplied' do
    expect(subject * 5).to eq 0
    expect(5 * subject).to eq 0
  end

  it 'can be negated' do
    int = Dart::Integer.new(5)
    expect(-int).to be -5
  end
end

RSpec.describe Dart::Decimal do
  it 'is a decimal' do
    expect(subject.dcm?).to be true
    expect(subject.get_type).to be :decimal
  end

  it 'starts as zero' do
    expect(subject).to eq 0.0
    expect(0.0).to eq subject
  end

  it 'can be multiplied' do
    expect(subject * 5).to eq 0.0
    expect(5 * subject).to eq 0.0
  end

  it 'can be negated' do
    dcm = Dart::Decimal.new(5.5)
    expect(-dcm).to be -5.5
  end
end
