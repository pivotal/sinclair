require 'spec_helper'

describe Sinclair::OpenAirApiClient do
  subject  { Sinclair::OpenAirApiClient.new(username: 'Username', password: 'Password', company: 'Company', client: 'Client', key: 'APIKEY', limit: '5') }
  let(:template) { IO.read("#{ File.expand_path('../templates', __FILE__) }/#{ template_name }") }

  describe '#send_request' do
    context 'when the request is empty' do
      let!(:template_name) { 'client_request.xml.erb' }

      before do
        stub_xml_request(
          request: 'clients_request',
          response: 'clients_empty_response'
        )
      end

      it 'returns an empty array' do
        response = subject.send_request(template: template, key: 'Customer')
        expect(response).to be_empty
      end
    end

    context 'when the request contains one command' do
      let!(:template_name) { 'client_request.xml.erb' }

      context 'when the response contains one item' do
        before do
          stub_xml_request(
            request: 'clients_request',
            response: 'clients_response'
          )
        end

        it 'returns an array of one item' do
          response = subject.send_request(template: template, key: 'Customer')
          expect(response.map { |client| client['name'] }).to match_array(['Client 1'])
        end
      end

      context 'when the response contains multiple items' do
        before do
          stub_xml_request(
            request: 'all_clients_multiple_request_1',
            response: 'all_clients_multiple_response_1'
          )

          stub_xml_request(
            request: 'all_clients_multiple_request_2',
            response: 'all_clients_multiple_response_2'
          )
        end

        it 'makes multiple requests when the number of responses is greater than the limit' do
          response = subject.send_request(template: template, key: 'Customer')
          names = response.map { |client| client['name'] }

          expect(names).to match_array(['Blah Client', 'Client 1', 'Client 2', 'Client 3', 'Client 4', 'Client 5', 'Fancy Client'])
        end
      end
    end

    context 'when the request contains multiple commands' do
      let!(:template_name) { 'client_multiple_commands_request.xml.erb' }

      before do
        stub_xml_request(
          request: 'clients_multiple_commands_request',
          response: 'clients_multiple_commands_response'
        )
      end

      it 'returns an array of all items' do
        response = subject.send_request(template: template, key: 'Customer', locals: { customer_ids: [1, 2] })
        expect(response.map { |client| client['name'] }).to match_array(['Customer 1', 'Customer 2'])
      end
    end

    context 'when an error occurs' do
      let!(:template_name) { 'client_request.xml.erb' }

      it 'raises a OpenAirResponseUnrecognized error when the response is malformed' do
        stub_xml_request(
          request: 'all_clients_single_request',
          response: 'all_clients_single_error'
        )

        expect {
          subject.send_request(template: template, key: 'Client')
        }.to raise_error(Sinclair::OpenAirResponseUnrecognized)
      end

      it 'raises a OpenAirUserLocked error when the response status is 416' do
        stub_xml_request(
          request: 'all_clients_single_request',
          response: 'all_clients_locked_error'
        )

        expect {
          subject.send_request(template: template, key: 'Client')
        }.to raise_error(Sinclair::OpenAirUserLocked)
      end

      it 'raises a OpenAirAuthenticationFailure error when the response status not zero' do
        stub_xml_request(
          request: 'all_clients_single_request',
          response: 'all_clients_auth_error'
        )

        expect {
          subject.send_request(template: template, key: 'Client')
        }.to raise_error(Sinclair::OpenAirAuthenticationFailure)
      end

      it 'raises a OpenAirResponseTimeout error when OpenAir times out' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)

        expect {
          subject.send_request(template: template, key: 'Client')
        }.to raise_error(Sinclair::OpenAirResponseTimeout)
      end

      it 'raises a OpenAirResponseError when the read status is not zero' do
        stub_xml_request(
          request: 'all_clients_single_request',
          response: 'all_clients_read_error'
        )

        expect {
          subject.send_request(template: template, key: 'Client')
        }.to raise_error(Sinclair::OpenAirResponseError, 'Error making OpenAir request. Got status 602.')
      end

      it 'does not raise an error when the read status is 601' do
          stub_xml_request(
            request: 'all_clients_single_request',
            response: 'all_clients_read_601_error'
          )

          expect {
            subject.send_request(template: template, key: 'Client')
          }.not_to raise_error
        end
    end
  end
end
