# Install required Vagrant plugins
missing_plugins_installed = false
required_plugins = %w(vagrant-cachier vagrant-hostsupdater)

required_plugins.each do |plugin|
  if !Vagrant.has_plugin? plugin
    system "vagrant plugin install #{plugin}"
    missing_plugins_installed = true
  end
end

# If any plugins were missing and have been installed, re-run vagrant
if missing_plugins_installed
  exec "vagrant #{ARGV.join(" ")}"
end

Vagrant.configure(2) do |config|
  config.vm.define :lab_hack_lfi do |lab_hack_lfi|
    lab_hack_lfi.vm.box = "generic/debian10"
    lab_hack_lfi.vm.hostname = "lab-hack-lfi"
    lab_hack_lfi.vm.network :private_network, ip: "10.10.10.10"
    lab_hack_lfi.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
    config.vm.provision "file", source: "./site", destination: "$HOME/site"
    lab_hack_lfi.vm.provision :shell, path: "provision/lab-hack-lfi.sh"
  end
end
