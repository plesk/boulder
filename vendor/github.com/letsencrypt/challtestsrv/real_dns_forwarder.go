package challtestsrv

import (
	"context"
	"net"
	"time"

	"github.com/miekg/dns"
)

// RealDNSForwarder forwards DNS queries to real upstream DNS servers
type RealDNSForwarder struct {
	upstreamServers []string
	client          *dns.Client
}

// NewRealDNSForwarder creates a new forwarder that will use the provided upstream DNS servers
func NewRealDNSForwarder(upstreamServers []string) *RealDNSForwarder {
	if len(upstreamServers) == 0 {
		// Default to Google and Cloudflare public DNS
		upstreamServers = []string{"8.8.8.8:53", "1.1.1.1:53"}
	}

	return &RealDNSForwarder{
		upstreamServers: upstreamServers,
		client: &dns.Client{
			Net:     "udp",
			Timeout: 5 * time.Second,
		},
	}
}

// ForwardQuery sends the DNS query to real upstream DNS servers
// Returns the answer records from the first successful response
func (f *RealDNSForwarder) ForwardQuery(q dns.Question) []dns.RR {
	msg := new(dns.Msg)
	msg.SetQuestion(q.Name, q.Qtype)
	msg.RecursionDesired = true

	// Try each upstream server until we get a response
	for _, server := range f.upstreamServers {
		resp, _, err := f.client.Exchange(msg, server)
		if err != nil {
			continue
		}

		if resp != nil && resp.Rcode == dns.RcodeSuccess {
			return resp.Answer
		}
	}

	// No successful response from any server
	return nil
}

// ForwardQueryWithContext sends the DNS query with context support for timeout/cancellation
func (f *RealDNSForwarder) ForwardQueryWithContext(ctx context.Context, q dns.Question) []dns.RR {
	msg := new(dns.Msg)
	msg.SetQuestion(q.Name, q.Qtype)
	msg.RecursionDesired = true

	// Create a dialer that respects the context
	dialer := &net.Dialer{}

	for _, server := range f.upstreamServers {
		// Check if context is already cancelled
		select {
		case <-ctx.Done():
			return nil
		default:
		}

		conn, err := dialer.DialContext(ctx, "udp", server)
		if err != nil {
			continue
		}

		dnsConn := &dns.Conn{Conn: conn}
		err = dnsConn.WriteMsg(msg)
		if err != nil {
			dnsConn.Close()
			continue
		}

		resp, err := dnsConn.ReadMsg()
		dnsConn.Close()

		if err == nil && resp != nil && resp.Rcode == dns.RcodeSuccess {
			return resp.Answer
		}
	}

	return nil
}
