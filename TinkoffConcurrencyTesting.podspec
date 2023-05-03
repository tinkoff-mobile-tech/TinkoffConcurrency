Pod::Spec.new do |s|
  s.name             = 'TinkoffConcurrencyTesting'
  s.version          = '1.2.0'
  s.summary          = 'A toolset that makes Swift Concurrency testing a bit easier.'

  s.description      = <<-DESC
                     A set of tools that would help testing parts of code combining synchronous and asynchronous parts
                       DESC

  s.homepage         = 'https://github.com/tinkoff-mobile-tech/TinkoffConcurrency'
  s.license          = { :type => 'Apache License 2.0', :file => 'LICENSE' }
  s.author           = { 'Timur Khamidov' => 't.khamidov@tinkoff.ru',
                         'Aleksandr Darovskikh' => 'ext.adarovskikh@tinkoff.ru' }
  s.source           = { :git => 'https://github.com/tinkoff-mobile-tech/TinkoffConcurrency.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  # s.watchos.deployment_target = '6.0'
  s.tvos.deployment_target = '13.0'
  s.swift_version = '5.5'

  s.source_files = 'Development/TinkoffConcurrencyTesting/**/*.{swift,md,docc}'
  
  s.dependency 'TinkoffConcurrency', '~> 1.2.0'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = ["Tests/TinkoffConcurrencyTesting/**/*.swift", "Tests/TestSupport/**/*.swift"]
  end
end
