require 'docker'

describe 'stop_signal' do
  after(:each) do
    run "kontena stack rm --force simple"
  end

  it 'stops container with user-defined signal' do
    with_fixture_dir("stack/stop_signal") do
      k = run 'kontena stack install --deploy'
      k.wait

      k = run 'kontena stack stop simple'
      k.wait
      container = Docker::Container.all({all: true}).find { |c|
        c.info['Names'].find { |e| /simple/ =~ e } != nil
      }
      exit_code = container.info['ExitCode']
      expect(exit_code).to eq(0)
    end
  end
end
