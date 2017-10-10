require 'json'

describe 'stop_signal' do
  after(:each) do
    run "kontena stack rm --force simple"
  end

  it 'stops container with user-defined signal' do
    with_fixture_dir("stack/stop_signal") do
      k = run 'kontena stack install --deploy'
      k.wait

      id = container_id('simple.app-1')

      k = run "kontena container inspect #{id}"
      expect(JSON.parse(k.out).dig('Config', 'StopSignal')).to eq('SIGINT')
    end
  end
end
