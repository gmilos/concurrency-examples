package example

import "fmt"
import "errors"
import "math/rand"
import "time"

type Request struct{}
type Response struct {
	id int
}

var (
	NoDownstreamService         = errors.New("No downstream service")
	AllDownstreamServicesFailed = errors.New("All downstream services failed")
)

type DelayService struct {
	id    int
	delay time.Duration
}

func NewDelayService(id int) DelayService {
	return DelayService{id: id, delay: time.Duration(int(rand.Float64()*1000)) * time.Millisecond}
}

func (ds *DelayService) Service(req *Request) (*Response, error) {
	time.Sleep(ds.delay)
	return &Response{id: ds.id}, nil
}

type FirstResponseService struct {
	downstreamServices []DelayService
}

func NewFirstResponseService(downstreamServices []DelayService) FirstResponseService {
	return FirstResponseService{downstreamServices: downstreamServices}
}

type result struct {
	resp *Response
	err  error
}

func (frs *FirstResponseService) Service(req *Request) (*Response, error) {
	if len(frs.downstreamServices) == 0 {
		return nil, NoDownstreamService
	}
	results := make(chan result)
	for _, s := range frs.downstreamServices {
		go func(s DelayService) {
			resp, err := s.Service(req)
			results <- result{resp: resp, err: err}
		}(s)
	}
	for _ = range frs.downstreamServices {
		result := <-results
		resp, _ := result.resp, result.err
		if resp != nil {
			return resp, nil
		}
	}
	return nil, AllDownstreamServicesFailed
}

func main() {
	rand.Seed(int64(time.Now().Nanosecond()))
	var downstreamServices []DelayService
	for i := 0; i < 50; i++ {
		downstreamServices = append(downstreamServices, NewDelayService(i))
	}
	frs := NewFirstResponseService(downstreamServices)
	resp, _ := frs.Service(&Request{})
	fmt.Printf("%v\n", resp.id)
}
