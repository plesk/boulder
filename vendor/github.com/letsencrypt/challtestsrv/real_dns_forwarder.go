package challtestsrv

import (
	"fmt"
	"log"
	"net"
	"time"

	"github.com/miekg/dns"
)

// RealDNSForwarder handles forwarding DNS queries to upstream DNS servers
type RealDNSForwarder struct {
	log             *log.Logger
	upstreamServers []string
	timeout         time.Duration
}

// NewRealDNSForwarder creates a new RealDNSForwarder instance
func NewRealDNSForwarder(log *log.Logger, upstreamServers []string) *RealDNSForwarder {
	return &RealDNSForwarder{
		log:             log,
		upstreamServers: upstreamServers,
		timeout:         5 * time.Second,
	}
}

// ForwardQuery forwards a DNS query to upstream servers and returns the answers
// queryType should be dns.TypeA, dns.TypeAAAA, etc.
func (f *RealDNSForwarder) ForwardQuery(hostname string, queryType uint16) ([]dns.RR, error) {
	if len(f.upstreamServers) == 0 {
		return nil, fmt.Errorf("no upstream DNS servers configured")
	}

	// Create DNS query message
	msg := new(dns.Msg)
	msg.SetQuestion(dns.Fqdn(hostname), queryType)
	msg.RecursionDesired = true

	queryTypeName := dns.TypeToString[queryType]
	f.log.Printf("[REAL DNS FORWARDING] Forwarding %s query for %s to upstream servers %v",
		queryTypeName, hostname, f.upstreamServers)

	// Try each upstream server until one succeeds
	var lastErr error
	for _, server := range f.upstreamServers {
		// Ensure server has port
		if _, _, err := net.SplitHostPort(server); err != nil {
			server = net.JoinHostPort(server, "53")
		}

		client := &dns.Client{
			Timeout: f.timeout,
		}

		response, _, err := client.Exchange(msg, server)
		if err != nil {
			f.log.Printf("[REAL DNS FORWARDING] Error querying %s: %v", server, err)
			lastErr = err
			continue
		}

		if response == nil || response.Rcode != dns.RcodeSuccess {
			if response != nil {
				f.log.Printf("[REAL DNS FORWARDING] Non-success response from %s: %s",
					server, dns.RcodeToString[response.Rcode])
				lastErr = fmt.Errorf("DNS server returned: %s", dns.RcodeToString[response.Rcode])
			} else {
				f.log.Printf("[REAL DNS FORWARDING] Empty response from %s", server)
				lastErr = fmt.Errorf("empty response from DNS server")
			}
			continue
		}

		// Success! Return the answer records
		f.log.Printf("[REAL DNS FORWARDING] Received %d answer(s) for %s %s query from %s",
			len(response.Answer), hostname, queryTypeName, server)

		return response.Answer, nil
	}

	// All servers failed
	if lastErr != nil {
		return nil, fmt.Errorf("all upstream DNS servers failed, last error: %w", lastErr)
	}
	return nil, fmt.Errorf("all upstream DNS servers failed")
}
