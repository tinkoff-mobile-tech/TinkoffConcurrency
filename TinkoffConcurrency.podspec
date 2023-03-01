Pod::Spec.new do |s|
  s.name             = 'TinkoffConcurrency'
  s.version          = '0.0.1'
  s.summary          = 'A toolset that makes Swift Concurrency a bit easier.'

  s.description      = <<-DESC
                     A set of handful tools that would help adopting an existing codebase to Swift Concurrency, including
                       * A general-purpose cancellables storage
                       * A robust `withTrowingContinuation` alternative that supports task cancelling and converts all cancelling
                         contracts to Swift Concurrency requirements.
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

  s.source_files = 'Development/Source/**/*.swift'

  s.test_spec 'Tests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = "Tests/**/*.swift"
  end
end
