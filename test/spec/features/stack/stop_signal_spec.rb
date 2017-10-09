describe 'stop_signal' do
  after(:each) do
    run "kontena stack rm --force simple"
  end

  it 'stops container with user-defined signal', :focus => true do
    with_fixture_dir("stack/stop_signal") do
      k = run 'kontena stack install --deploy'
      k.wait
      expect(k.code).to eq(0)

      id = container_id('simple.app-1')

      run 'kontena stack stop simple'
      k = run "kontena container inspect #{id}"
      expect(k.code).to eq(0)
      expect(k.out).to match(/^\s+\"ExitCode\"\:\s+0\,$/)
    end
  end
end
