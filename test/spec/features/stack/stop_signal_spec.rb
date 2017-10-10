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
      json = inspect_all(id)
      exit_code = JSON.parse(json).dig('ExitCode')
      expect(exit_code).to eq(0)
    end
  end
end
