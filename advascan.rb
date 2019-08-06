#!/usr/bin/env ruby

require 'pty'
require 'expect'

require 'rubygems'
require 'optparse'


$expect_verbose = false


TIOCGWINSZ = 0x5413

def get_console_cols_rows

    cols = 130
    rows = 40
    begin
        buf = [0, 0, 0, 0].pack("SSSS")
        if STDOUT.ioctl(TIOCGWINSZ, buf) >= 0 then
            rows, cols, row_pixels, row_pixels, col_pixels = buf.unpack("SSSS")[0..1]
        end
    rescue
    end
    return cols,rows

end


interfaces = []

optparse = OptionParser.new do|opts|
    opts.on( '-i', '--interface IP_interface', " Address" ) do|f|
        interfaces << f
    end
    opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
    end
end


optparse.parse!

if interfaces.empty? 
    raise "no interfaces given"
end

puts "\n\n"

user = ""
pass = ""

require 'io/console'
print "User:      "
user = STDIN.gets.chomp
print "Password:  "
pass = STDIN.noecho(&:gets).chomp
puts "\n"

trap('INT') do
    print "\e[1G" # jump to the start of the line
    100.times {print "\e[B"} # print 100 linebreaks (with disabled scrolling)
    exit
end

puts "\e[39m\e[2J" #  set default colour and clear screen
print "\e[3;1H\n" # jump to position 1:1

connections = []
interfaces.each do |interface|
    ip = interface.split('_')[0]
    filter = Regexp.new(interface.split('_')[1])

    reader, writer, pid = PTY.spawn("ssh #{user}@#{ip} -o ConnectTimeout=5 -o StrictHostKeyChecking=no")

    reader.expect(/.assword: ?/){ |a|
        writer.puts(pass)
    }
    reader.expect(/\n#{user}@.*> /){|a|
        writer.puts("show interface")
    }
    matches = []

    reader.expect(/\n#{user}@.*> /){|a|

        matches = a[0].scan(/\r\r\n\d\/\d\/[cn]\d+ /).map{|x| x.strip}
        matches = matches.delete_if{|x| not filter.match(x) }
        writer.puts("")
    }
    connections << [ reader, writer, pid, matches, ip ]
end


loop do

    print "\e[1;1H\e[K\n" #jump to 1:1 and clear first line
    print " Interface                               IN            OUT            SNR            CD\e[K\n" 

    cols,rows = get_console_cols_rows
    #printheader
    (cols-2).times{print "-"}
    print "\n\e[K\n"

    connections.each do |connection|
        reader = connection[0]
        writer = connection[1]
        pid = connection[2]
        interfaces = connection[3]
        ip = connection[4]


        interfaces.each do | interface |

            out_level = nil
            in_level = nil
            snr = nil
            cd = nil
            channel = "0"

            type = ""
            reader.expect(/\n#{user}@.*> /){|a|
                writer.puts("show interface #{interface} opt-phy")
            }
            reader.expect(/\n#{user}@.*> /){|a|

                channel = a[0].match(/frequency: (\d+\.?\d+) THz/)
                writer.puts("show interface #{interface} opt-phy pm current")
            }
            reader.expect(/\n#{user}@.*> /){|a|
                in_level = a[0].match(/opt-rx-pwr .* (-?\d+\.?\d?) dBm/)
                out_level = a[0].match(/opt-tx-pwr .* (-?\d+\.?\d?) dBm/)
                if in_level == nil && out_level == nil
                    writer.puts("show interface #{interface} optm-phy pm current")
                    reader.expect(/\n#{user}@.*> /){|a|
                        in_level = a[0].match(/opt-rx-pwr .* (-?\d+\.?\d?) dBm/)
                        out_level = a[0].match(/opt-tx-pwr .* (-?\d+\.?\d?) dBm/)
                    }
                end
                writer.puts("show interface #{interface}/ot100 och pm current")
            }
            reader.expect(/\n#{user}@.*> /){|a|
                snr = a[0].match(/signal-to-noise-ratio .* (-?\d+\.?\d?) dB/)
                cd = a[0].match(/chromatic-dispersion-compensation .* (-?\d+\.?\d?) ps\/nm/)
                type = "ot100"
                if snr == nil && cd == nil
                    writer.puts("show interface #{interface}/ot200 och pm current")
                    reader.expect(/\n#{user}@.*> /){|a|
                        type = "ot200"
                        snr = a[0].match(/signal-to-noise-ratio .* (-?\d+\.?\d?) dB/)
                        cd = a[0].match(/chromatic-dispersion-compensation .* (-?\d+\.?\d?) ps\/nm/)
                    }
                end
                writer.puts("")
            }

            print " #{ ip.ljust(22)} "
            print "#{ interface.ljust(20)} "
            print "#{ (channel ? channel[1] : "-").ljust(15)} "
            print "#{ type.ljust(30)} "
            print "#{ (in_level ? in_level[1] : "-").rjust(10)} dBm "
            print "#{ (out_level ? out_level[1] : "-").rjust(10)} dBm "
            print "#{ (snr ? snr[1] : "-").rjust(10)} dB "
            print "#{ (cd ? cd[1] : "-").rjust(10)} ps/nm "
            print "\e[K\n"

        end
    end

end

exit


#!/usr/bin/env ruby

require 'rubygems'
require 'snmp'
require 'yaml'

class Integer
    def byte_to_Mbit
        return (self * 8 / 1024 / 1024) 
    end
end



begin
    SNMP::Manager.open(:Host => h_opt , :Community => c_opt , :Timeout => 1 , :Retries => 600) do |manager| 

        while 1


        end
    end
rescue SNMP::RequestTimeout

    print "\e[1G" # an den Anfang der zeile springen um in die erste Spalte zu kommen
    100.times {print "\e[B"} # ans ende vom Terminal springen
    puts "Timeout for 600s"
    exit

end
