require 'sinatra'
require 'erb'
require 'open-uri'
require 'xmlsimple'

get '/' do
    erb :home
end

post '/search' do
    @latitude = params[:latitude].to_f
    @longitude = params[:longitude].to_f

    # Get all stations
    xml = open 'http://www.velib.paris.fr/service/carto'
    data = XmlSimple.xml_in xml.read
    markers = data['markers'][0]['marker']

    # Remove closed stations
    markers = markers.delete_if do |markers|
        markers['open'] == 0
    end

    # Calculate distance in meters between stations and me
    R = 6371000 # Earth radius in meters
    markers.each do |marker|
        distance = Math::sin((marker['lat'].to_f - @latitude) / 360 * Math::PI)**2 + Math::sin((marker['lng'].to_f - @longitude) / 360 * Math::PI)**2 * Math::cos(@latitude / 180 * Math::PI) * Math::cos(marker['lat'].to_f / 180 * Math::PI)
        distance = R * 2 * Math::atan2(Math::sqrt(distance), Math::sqrt(1-distance))
        marker['distance'] = distance
    end

    # Sort stations by distance
    markers = markers.sort_by do |marker|
        marker['distance']
    end

    # Keep only 10 closest stations
    markers = markers[0, 10]

    # Format results
    @stations = []
    markers.each do |marker|
        xml = open 'http://www.velib.paris.fr/service/stationdetails/' + marker['number']
        data = XmlSimple.xml_in xml.read

        station = {
            :name => marker['name'][8,marker['name'].length],
            :address => marker['address'][0,marker['address'].length-2],
            :fullAddress => marker['fullAddress'],
            :distance => marker['distance'].to_i,
            :available => data['available'][0].to_i,
            :free => data['free'][0].to_i
        }
        @stations << station
    end

    erb :search, :layout => false
end
