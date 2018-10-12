def build_services_for_algolia(application_id: '42', api_key: '42', indices: [])
  request = instance_double('Request', env: {})
  site    = instance_double('Site', metafields: {
    'algolia' => {
      'application_id'  => application_id,
      'api_key'         => api_key,
      'indices'         => indices
    }
  })

  allow_any_instance_of(Locomotive::Steam::SiteFinderService).to receive(:find).and_return(site)

  Locomotive::Steam::Services.build_instance(request)
end

def build_services_for_erp(api_url: 'http://models.example.com/shopinvader', api_key: '42', session: nil)
  request = instance_double('Request',
      env: {
        'rack.session' => session,
      },
      get_header: "foo",
      ip: '42.42.42.42',
      )
  site    = instance_double('Site', metafields: {
    'erp' => {
      'api_url'  => api_url,
      'api_key'  => api_key
    }
  })

  allow_any_instance_of(Locomotive::Steam::SiteFinderService).to receive(:find).and_return(site)

  Locomotive::Steam::Services.build_instance(request)
end
