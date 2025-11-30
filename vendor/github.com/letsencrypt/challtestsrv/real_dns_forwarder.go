package challtestsrv

import (
	"context"
	"log"
	"net"
	"time"

	"github.com/miekg/dns"
)

// RealDNSForwarder forwards DNS queries to real upstream DNS servers
type RealDNSForwarder struct {
	upstreamServers []string
	client          *dns.Client
	log             *log.Logger
}

// NewRealDNSForwarder creates a new forwarder that will use the provided upstream DNS servers
func NewRealDNSForwarder(upstreamServers []string, logger *log.Logger) *RealDNSForwarder {
	if len(upstreamServers) == 0 {
		// Default to Google and Cloudflare public DNS
		upstreamServers = []string{"8.8.8.8:53", "1.1.1.1:53"}
	}

	if logger != nil {
		logger.Printf("Created RealDNSForwarder with upstream servers: %v", upstreamServers)
	}

	return &RealDNSForwarder{
		upstreamServers: upstreamServers,
		client: &dns.Client{
			Net:     "udp",
			Timeout: 5 * time.Second,
		},
		log: logger,
	}
}

// ForwardQuery sends the DNS query to real upstream DNS servers
// Returns the answer records from the first successful response
func (f *RealDNSForwarder) ForwardQuery(q dns.Question) []dns.RR {
	msg := new(dns.Msg)
	msg.SetQuestion(q.Name, q.Qtype)
	msg.RecursionDesired = true

	if f.log != nil {
		f.log.Printf("Forwarding DNS query: %s %s to upstream servers", dns.TypeToString[q.Qtype], q.Name)
	}

	// Try each upstream server until we get a response
	for _, server := range f.upstreamServers {
		resp, rtt, err := f.client.Exchange(msg, server)
		if err != nil {
			if f.log != nil {
				f.log.Printf("DNS query to %s failed: %v", server, err)
			}
			continue
		}

		if resp != nil && resp.Rcode == dns.RcodeSuccess {
			if f.log != nil {
				f.log.Printf("DNS query successful via %s (rtt: %v), got %d answers for %s", server, rtt, len(resp.Answer), q.Name)
			}
			return resp.Answer
		} else if resp != nil {
			if f.log != nil {
				f.log.Printf("DNS query to %s returned rcode: %s", server, dns.RcodeToString[resp.Rcode])
			}
		}
	}

	// No successful response from any server
	if f.log != nil {
		f.log.Printf("No successful response from any upstream server for %s", q.Name)
	}
	return nil
}

// ForwardQueryWithContext sends the DNS query with context support for timeout/cancellation
func (f *RealDNSForwarder) ForwardQueryWithContext(ctx context.Context, q dns.Question) []dns.RR {
	msg := new(dns.Msg)
	msg.SetQuestion(q.Name, q.Qtype)
	msg.RecursionDesired = true

	if f.log != nil {
		f.log.Printf("Forwarding DNS query with context: %s %s", dns.TypeToString[q.Qtype], q.Name)
	}

	// Create a dialer that respects the context
	dialer := &net.Dialer{}

	for _, server := range f.upstreamServers {
		// Check if context is already cancelled
		select {
		case <-ctx.Done():
			if f.log != nil {
				f.log.Printf("Context cancelled while querying %s", q.Name)
			}
			return nil
		default:
		}

		conn, err := dialer.DialContext(ctx, "udp", server)
		if err != nil {
			if f.log != nil {
				f.log.Printf("Failed to dial %s: %v", server, err)
			}
			continue
		}

		dnsConn := &dns.Conn{Conn: conn}
		err = dnsConn.WriteMsg(msg)
		if err != nil {
			if f.log != nil {
				f.log.Printf("Failed to write DNS message to %s: %v", server, err)
			}
			dnsConn.Close()
			continue
		}

		resp, err := dnsConn.ReadMsg()
		dnsConn.Close()

		if err == nil && resp != nil && resp.Rcode == dns.RcodeSuccess {
			if f.log != nil {
				f.log.Printf("DNS query with context successful via %s, got %d answers for %s", server, len(resp.Answer), q.Name)
			}
			return resp.Answer
		} else if err != nil {
			if f.log != nil {
				f.log.Printf("Failed to read DNS response from %s: %v", server, err)
			}
		}
	}

	if f.log != nil {
		f.log.Printf("No successful response with context from any upstream server for %s", q.Name)
	}
	return nil
}
