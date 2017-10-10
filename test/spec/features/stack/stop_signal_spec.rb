require 'docker'

describe 'stop_signal' do
  after(:each) do
    run "kontena stack rm --force simple"
  end

  it 'stops container with user-defined signal' do
    with_fixture_dir("stack/stop_signal") do
      run 'kontena stack install --deploy'
      sleep 1
      k = run 'kontena container list -q --all'
      id = k.out.match("^(.+\/simple)")[1]

      run 'kontena stack stop'
      container = Docker::Container.all({all: true}).find { |c|
        JSON.parse(c.info).Names.find { |e| /simple/ =~ e } != nil
      }
      exit_code = JSON.parse(container.info).dig('ExitCode')
      expect(exit_code).to eq(0)
    end
  end
end
