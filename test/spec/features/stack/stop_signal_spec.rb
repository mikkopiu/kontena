describe 'service link' do
  after(:each) do
    run "kontena stack rm --force stop_signal"
  end

  it 'stops container with user-defined signal' do
    with_fixture_dir("stack/stop_signal") do
      run 'kontena stack install'
      sleep 1
      id = container_id('stop_signal')

      run 'kontena stack stop'
      k = run "kontena container inspect #{id}"
      expect(k.out.match(/^\s+\"ExitCode\"\:\s+0\,$/)).to be_truthy
    end
  end
end
