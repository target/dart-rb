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

    hsh = {hello: 'goodbye'}
    expect(subject).to eq hsh
    expect(hsh).to eq subject
    hsh[:hello] = 'world'
    expect(subject).to_not eq hsh
    expect(hsh).to_not eq subject
  end

  it 'is not unwrappable' do
    expect { subject.unwrap }.to raise_error NoMethodError
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

    arr = [nil, nil, nil, 'goodbye']
    expect(subject).to eq arr
    expect(arr).to eq subject
    arr.shift
    expect(subject).to_not eq arr
    expect(arr).to_not eq subject
  end

  it 'is not unwrappable' do
    expect { subject.unwrap }.to raise_error NoMethodError
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

RSpec.describe Dart::String do
  let(:saying) { Dart::String.new('the rain in Spain lays mainly on the plain') }

  it 'is a string' do
    expect(saying.str?).to be true
    expect(saying.get_type).to be :string
  end

  # Generate all other type checks.
  generate_type_tests(binding, except: 'string')

  it 'starts out empty' do
    expect(subject.empty?).to be true
  end

  it 'can access characters' do
    expect(saying[3]).to eq ' '
    expect(saying[4...8]).to eq 'rain'
  end

  it 'can report its size' do
    expect(saying.size).to be 42
  end

  it 'is comparable' do
    str = 'the rain in Spain lays mainly on the plain'
    expect(saying).to eq str
    expect(str).to eq saying
  end

  it 'is unwrappable' do
    expect(saying.unwrap).to eq 'the rain in Spain lays mainly on the plain'
  end
end

RSpec.describe Dart::Integer do
  let(:five) { Dart::Integer.new(5) }

  it 'can be safely constructed' do
    expect(Dart::Integer.new(10)).to eq 10
    expect { Dart::Integer.new(5.5) }.to raise_error ArgumentError
  end

  it 'is an integer' do
    expect(subject.int?).to be true
    expect(subject.get_type).to be :integer
  end

  # Generate all other type checks.
  generate_type_tests(binding, except: 'integer')

  it 'starts as zero' do
    expect(subject).to eq 0
    expect(0).to eq subject
  end

  it 'can be unwrapped' do
    expect(subject.unwrap).to be 0
  end

  it 'can be added' do
    expect(five + 5).to eq 10
    expect(5 + five).to eq 10
  end

  it 'can be subtracted' do
    expect(five - 10).to eq -5
    expect(10 - five).to eq 5
  end

  it 'can be multiplied' do
    expect(five * 5).to eq 25
    expect(5 * five).to eq 25
  end

  it 'can be divided' do
    expect(five / 5).to eq 1
    expect(5 / five).to eq 1
  end

  it 'can be modded' do
    expect(five % 4).to eq 1
    expect(4 % five).to eq 4
  end

  it 'can be exponentiated' do
    expect(five ** 3).to eq 125
    expect(3 ** five).to eq 243
  end

  it 'can be masked' do
    expect(five & 0).to eq 0
    expect(0 & five).to eq 0
    expect(five | 7).to eq 7
    expect(7 | five).to eq 7
    expect(five ^ 5).to eq 0
    expect(5 ^ five).to eq 0
  end

  it 'can be compared' do
    expect(five).to be > 4
    expect(five).to be >= 5
    expect(five).to be < 6
    expect(five).to be <= 5
  end

  it 'can be negated' do
    expect(-five).to be -5
    expect(~five).to be -6
  end
end

RSpec.describe Dart::Decimal do
  let(:half) { Dart::Decimal.new(0.5) }
  let(:pi) { Dart::Decimal.new(3.14159) }

  it 'is a decimal' do
    expect(subject.dcm?).to be true
    expect(subject.get_type).to be :decimal
  end

  # Generate all other type checks.
  generate_type_tests(binding, except: 'decimal')

  it 'starts as zero' do
    expect(subject).to eq 0.0
    expect(0.0).to eq subject
  end

  it 'can be unwrapped' do
    expect(subject.unwrap).to be 0.0
  end

  it 'can be added' do
    expect(half + 0.5).to be 1.0
    expect(0.5 + half).to be 1.0
  end

  it 'can be subtracted' do
    expect(half - 0.5).to be 0.0
    expect(0.5 - half).to be 0.0
  end

  it 'can be multiplied' do
    expect(half * 2).to be 1.0
    expect(2 * half).to be 1.0
  end

  it 'can be divided' do
    expect(1 / half).to be 2.0
    expect(half / 2).to be 0.25
  end

  it 'can be modded' do
    dcm = Dart::Decimal.new(5.5)
    expect(dcm % 4).to be 1.5
    expect(4 % dcm).to be 4.0
  end

  it 'can be exponentiated' do
    expect(half ** 4).to be 0.0625
    expect(4 ** half).to be 2.0
  end

  it 'cannot be masked' do
    expect { half & 0 }.to raise_error NoMethodError
    expect { 0 & half }.to raise_error TypeError
    expect { half | 7 }.to raise_error NoMethodError
    expect { 7 | half }.to raise_error TypeError
    expect { half ^ 1 }.to raise_error NoMethodError
    expect { 1 ^ half }.to raise_error TypeError
  end

  it 'can be compared' do
    expect(pi).to be > 3
    expect(pi).to be < 4
  end

  it 'can be negated' do
    expect(-pi).to be_within(0.01).of -3.14159
  end
end

RSpec.describe Dart::Boolean do
  it 'is a boolean' do
    expect(subject.bool?).to be true
    expect(subject.get_type).to be :boolean
  end

  # Generate all other type checks.
  generate_type_tests(binding, except: 'boolean')

  it 'starts out as false' do
    expect(subject).to eq false
  end

  it 'is comparable' do
    expect(subject).to eq false
  end

  it 'is unwrappable' do
    expect(subject.unwrap).to be false
  end
end

RSpec.describe Dart::Null do
  it 'is null' do
    expect(subject.null?).to be true
    expect(subject.get_type).to be :null
  end

  # Generate all other type checks.
  generate_type_tests(binding, except: 'null')
end
